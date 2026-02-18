# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:3.27.1 AS build

WORKDIR /app
COPY . .

RUN sudo chown -R cirrus:cirrus /app

USER cirrus

# Get dependencies
RUN flutter pub get

# Build web app
RUN flutter build web --release

# Stage 2: Serve the app with Nginx
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy built artifacts from the build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]