$contexts = @("minikube", "Administrator@my-eks-cluster.us-east-1.eksctl.io", "myAKSCluster")

foreach ($context in $contexts) {
    kubectl config use-context $context
    kubectl apply -f ningx-deployment.yaml
    kubectl apply -f nginx-service.yaml
    Write-Host "Deployed to $context"
}