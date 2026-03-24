FROM node:20-slim
WORKDIR /app
COPY package.json ./
RUN npm install --registry https://registry.npmjs.org
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["node", "dist/index.js"]
