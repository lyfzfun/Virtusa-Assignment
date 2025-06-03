Incremental & Decremental Counter on Kubernetes

Assumptions
- running this on Minikube.
- Docker image of the counter app is built and pushed to Docker Hub.
- Your MySQL schema is created on container startup.
- No code change needed from Scenario 1.


1. Clone this repo.
2. Install and run Docker and Kubernetes (minikube).
3. Build your app:
   
   docker build -t lyfzfun/counter:latest ./app
   docker push lyfzfun/counter:latest
