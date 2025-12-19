
set -e


GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Starting zero-downtime deployment...${NC}"

cd /opt/nnican_music_bot/deploy


CURRENT_REPLICAS=$(docker compose ps bot -q | wc -l)
echo -e "${YELLOW}📊 Current replicas: ${CURRENT_REPLICAS}${NC}"


echo -e "${YELLOW}📦 Pulling new image...${NC}"
docker compose pull bot


NEW_REPLICAS=$((CURRENT_REPLICAS + 1))
echo -e "${YELLOW}🔄 Scaling up to ${NEW_REPLICAS} replicas...${NC}"
docker compose up -d --scale bot=${NEW_REPLICAS} --no-recreate


echo -e "${YELLOW}⏳ Waiting for new instances to become healthy...${NC}"
MAX_WAIT=180  
WAITED=0
HEALTHY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    
    if curl -sf http://localhost:80/health/readiness > /dev/null; then
        HEALTHY=true
        break
    fi
    echo -e "${YELLOW}   Waiting... (${WAITED}s/${MAX_WAIT}s)${NC}"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ "$HEALTHY" = false ]; then
    echo -e "${RED}❌ New instances failed healthcheck. Rolling back...${NC}"
    docker compose up -d --scale bot=${CURRENT_REPLICAS} --no-recreate
    exit 1
fi

echo -e "${GREEN}✅ New instances are healthy!${NC}"


echo -e "${YELLOW}🔄 Scaling down to ${CURRENT_REPLICAS} replicas...${NC}"
docker compose up -d --scale bot=${CURRENT_REPLICAS} --no-recreate

echo -e "${YELLOW}🧹 Cleaning up old containers...${NC}"
docker compose ps -q bot | tail -n +$((CURRENT_REPLICAS + 1)) | xargs -r docker stop
sleep 10  
docker compose ps -q -a bot | grep -v "$(docker compose ps -q bot)" | xargs -r docker rm

echo -e "${YELLOW}🔍 Final health check...${NC}"
if curl -sf http://localhost:80/health/readiness > /dev/null; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    
    docker compose ps bot
    
    echo -e "\n${YELLOW}📋 Recent logs:${NC}"
    docker compose logs --tail=20 bot
else
    echo -e "${RED}❌ Final health check failed!${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Zero-downtime deployment complete!${NC}"
