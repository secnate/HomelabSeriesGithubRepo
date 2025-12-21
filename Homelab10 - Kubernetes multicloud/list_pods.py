from kubernetes import client, config
import csv
from datetime import datetime

def list_all_pods():
    # Load kubernetes configuration
    config.load_kube_config()

    # Create API client
    v1 = client.CoreV1Api()

    # Get the current context
    contexts, active_context = config.list_kube_config_contexts()

    # Checking for the case where we have no Kubernetes contexts
    if not contexts:
        print("Cannot find any context in kube-config file.")
        return

    # Now we get information regarding the name of the cluster appropriately
    cluster_name = active_context['name']
    
    print("Cluster: {0}".format(cluster_name))
    print("-" * 80)

    # Collect pod data
    pods_data = []

    # Get all namespaces
    namespaces = v1.list_namespace()

    for ns in namespaces.items:
        namespace = ns.metadata.name
        pods = v1.list_namespaced_pod(namespace)

        for pod in pods.items:
            pod_info = {
                'Cluster': cluster_name,
                'Namespace': namespace,
                'Pod Name': pod.metadata.name,
                'Status': pod.status.phase,
                'IP': pod.status.pod_ip,
                'Node': pod.spec.node_name,
                'Created': pod.metadata.creation_timestamp
            }
            pods_data.append(pod_info)

            print("{0}/{1}: {2}".format(namespace, pod.metadata.name, pod.status.phase))
        
    return pods_data

# Function for exporting the data into CSV
def export_to_csv(pods_data, filename="pods_report.csv"):

    if not pods_data:
        print("No pods to export")
        return

    number_of_pods = len(pods_data)
    keys = pods_data[0].keys()
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=keys)
        writer.writeheader()
        writer.writerows(pods_data)

    print("\nExported {0} pods to {1}".format(number_of_pods, filename))

# Executing main program
if __name__ == "__main__":
    all_pods = list_all_pods()
    export_to_csv(all_pods)

