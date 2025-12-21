import asyncio
import logging
import signal

from aiogram import Bot, Dispatcher
from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application
from aiohttp import web

from app.models.config import AppConfig

logger = logging.getLogger(__name__)


_shutdown_event = asyncio.Event()


def setup_signal_handlers() -> None:
    def signal_handler(sig: int) -> None:
        sig_name = signal.Signals(sig).name
        logger.warning(f"Received signal {sig_name}, initiating graceful shutdown...")
        _shutdown_event.set()

    signal.signal(signal.SIGTERM, lambda s, f: signal_handler(s))

    signal.signal(signal.SIGINT, lambda s, f: signal_handler(s))


async def on_startup_webhook(dispatcher: Dispatcher, bot: Bot, config: AppConfig) -> None:
    webhook_url = f"{config.telegram.webhook_url}{config.telegram.webhook_path}"
    logger.info(f"Setting webhook: {webhook_url}")

    await bot.set_webhook(
        url=webhook_url,
        drop_pending_updates=config.telegram.drop_pending_updates,
        allowed_updates=dispatcher.resolve_used_update_types(),
    )
    logger.info("Webhook set successfully")


async def on_shutdown_webhook(bot: Bot) -> None:
    logger.info("Cleaning up webhook...")
    await bot.delete_webhook(drop_pending_updates=False)
    await bot.session.close()
    logger.info("Webhook cleanup complete")


def run_webhook(dispatcher: Dispatcher, bot: Bot, config: AppConfig) -> None:
    setup_signal_handlers()

    app = web.Application()

    async def health_liveness(request: web.Request) -> web.Response:
        """Liveness probe - процесс жив."""
        return web.json_response({"status": "alive", "service": "bot", "mode": "webhook"})

    async def health_readiness(request: web.Request) -> web.Response:
        """Readiness probe - готов обрабатывать запросы."""
        if _shutdown_event.is_set():
            return web.json_response({"status": "shutting_down", "ready": False}, status=503)

        try:
            bot_info = await bot.get_me()
            return web.json_response(
                {
                    "status": "ready",
                    "ready": True,
                    "service": "bot",
                    "bot_username": bot_info.username,
                }
            )
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return web.json_response({"status": "unhealthy", "ready": False, "error": str(e)}, status=503)

    app.router.add_get("/health/liveness", health_liveness)
    app.router.add_get("/health/readiness", health_readiness)

    SimpleRequestHandler(
        dispatcher=dispatcher,
        bot=bot,
    ).register(app, path=config.telegram.webhook_path)

    setup_application(app, dispatcher, bot=bot)

    dispatcher.startup.register(lambda: on_startup_webhook(dispatcher, bot, config))
    dispatcher.shutdown.register(lambda: on_shutdown_webhook(bot))

    logger.info(f"Starting webhook server on {config.server.host}:{config.server.port}")

    try:
        web.run_app(
            app,
            host=config.server.host,
            port=config.server.port,
            handle_signals=True,
            shutdown_timeout=30.0,
        )
    except (KeyboardInterrupt, SystemExit):
        logger.info("Shutdown complete")


async def _run_polling_async(dispatcher: Dispatcher, bot: Bot, config: AppConfig) -> None:
    await bot.delete_webhook(drop_pending_updates=config.telegram.drop_pending_updates)
    logger.info("Starting polling...")

    polling_task = asyncio.create_task(
        dispatcher.start_polling(
            bot,
            allowed_updates=dispatcher.resolve_used_update_types(),
        )
    )

    try:
        done, pending = await asyncio.wait(
            [polling_task, asyncio.create_task(_shutdown_event.wait())],
            return_when=asyncio.FIRST_COMPLETED,
        )

        if _shutdown_event.is_set():
            logger.info("Shutdown signal received, stopping polling...")

            polling_task.cancel()
            try:
                await polling_task
            except asyncio.CancelledError:
                logger.info("Polling stopped")

            logger.info("Waiting for handlers to complete...")
            await asyncio.sleep(5)

    except Exception as e:
        logger.exception(f"Error during polling: {e}")
        raise
    finally:
        await bot.session.close()
        logger.info("Polling shutdown complete")


def run_polling(dispatcher: Dispatcher, bot: Bot, config: AppConfig) -> None:
    setup_signal_handlers()

    try:
        asyncio.run(_run_polling_async(dispatcher, bot, config))
    except (KeyboardInterrupt, SystemExit):
        logger.info("Shutdown complete")


async def start_health_server(config: AppConfig) -> web.AppRunner:
    app = web.Application()

    async def health_liveness(request: web.Request) -> web.Response:
        return web.json_response({"status": "alive", "service": "bot", "mode": "polling"})

    async def health_readiness(request: web.Request) -> web.Response:
        if _shutdown_event.is_set():
            return web.json_response({"status": "shutting_down", "ready": False}, status=503)
        return web.json_response({"status": "ready", "ready": True})

    app.router.add_get("/health/liveness", health_liveness)
    app.router.add_get("/health/readiness", health_readiness)

    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, config.server.host, config.server.port)
    await site.start()

    logger.info(f"Health check server started on {config.server.host}:{config.server.port}")
    return runner
