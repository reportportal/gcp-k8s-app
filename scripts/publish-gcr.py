import yaml
import os
import subprocess

# Get the environment variables
values_file_path = os.getenv("VALUES_PATH")
schema_file_path = os.getenv("SCHEMA_PATH", "data/schema.yaml")
release_track = os.getenv("RELEASE_TRACK")
release_version = os.getenv("RELEASE_VERSION")
primary_image_service = os.getenv("PRIMARY_SERVICE", "")
old_repo = os.getenv("OLD_REPO", "reportportal")
new_registry = os.getenv("NEW_REGISTRY", "gcr.io")
new_repo = os.getenv("NEW_REPO", "epam-mp-rp/reportportal")
target_images = os.getenv("TARGET_IMAGES", "")
rpp_service_name = os.getenv("RPP_SERVICE_NAME", "services/reportportal.endpoints.epam-mp-rp.cloud.goog")

def load_yaml(file_path):
    with open(file_path, "r") as file:
        return yaml.safe_load(file)

def construct_image_name(registry, repository, tag):
    return (
        f"{registry}/{repository}:{tag}"
        if registry and not registry.endswith("/")
        else f"{registry}{repository}:{tag}"
    )

schema_file = load_yaml(schema_file_path)
values_file = load_yaml(values_file_path)

# Iterate over the images in schema.yaml
for gcr_image_name, value in schema_file["x-google-marketplace"]["images"].items():
    # Get the image key for mapping to the values.yaml
    properties = value["properties"]
    values_node = next(iter(properties)).split(".")[1]

    if target_images and values_node not in target_images:
        continue

    image = values_file[values_node].get("image")
    if image is None:
        print(f'Image: {values_node} not found in values.yaml\n')
        continue
    
    registry = image.get("registry", "")
    repository = image.get("repository", "")
    tag = image.get("tag", "")

    # Build the origin and new image names
    origin_image = construct_image_name(registry, repository, tag)

    if values_node == primary_image_service:
        new_image_track = construct_image_name(new_registry, new_repo, release_track)
        new_image_version = construct_image_name(new_registry, new_repo, release_version)
    else:
        new_image_track =  construct_image_name(new_registry, f"{new_repo}/{gcr_image_name}", release_track)
        new_image_version =  construct_image_name(new_registry, f"{new_repo}/{gcr_image_name}", release_version)

    # Pull the old image, tag it with the new image names, and push them to the new registry
    print(f'Key: {values_node}\nOrigin_image: {origin_image}\nNew_image_track: {new_image_track}\nNew_image_version: {new_image_version}')

    docker_pull = ['docker', 'pull', origin_image]
    docker_tag = ['docker', 'tag', origin_image]
    docker_push = ['docker', 'push']
    annotation_command = ['crane', 'mutate', '-a', 'com.googleapis.cloudmarketplace.product.service.name=' + rpp_service_name]
    
    commands = [
        # docker pull origin_image
        docker_pull,
        # docker tag origin_image new_image_track
        docker_tag + [new_image_track],
        # docker tag origin_image new_image_version
        docker_tag + [new_image_version],
        # docker push new_image_track
        docker_push + [new_image_track],
        # docker push new_image_version
        docker_push + [new_image_version],
        # crane mutate -a com.googleapis.cloudmarketplace.product.service.name=rpp_service_name new_image_track
        annotation_command + [new_image_track],
        # crane mutate -a com.googleapis.cloudmarketplace.product.service.name=rpp_service_name new_image_version
        annotation_command + [new_image_version]
    ]

    for command in commands:
        result = subprocess.run(command, stdout=subprocess.PIPE)
        if result.returncode != 0:
            print(f'Command: {command}\nError: {result.stdout.decode("utf-8")}')
            exit(1)
        else:
            print(f'Command: {command}\nSuccess: {result.stdout.decode("utf-8")}')
    
    print(f'Image: {new_image_track} and {new_image_version} pushed to {new_registry}\n')
