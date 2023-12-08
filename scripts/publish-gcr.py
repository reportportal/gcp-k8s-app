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
    # Get the repository and tag
    properties = value["properties"]
    keys = list(properties.keys())
    chart_value = keys[0].split(".")[1]

    for values_key, value in values_file.items():
        if values_key == chart_value:
            # Get a registry, repository and tag
            if isinstance(value, dict) and "image" in value:
                image = value["image"]
                registry = image.get("registry", "")
                repository = image.get("repository", "")
                tag = image.get("tag", "")

                # Construct the old and new image names
                old_image = construct_image_name(registry, repository, tag)

                if values_key == primary_image_service:
                    new_image_track = construct_image_name(new_registry, new_repo, release_track)
                    new_image_version = construct_image_name(new_registry, new_repo, release_version)
                else:
                    new_image_track =  construct_image_name(new_registry, f"{new_repo}/{gcr_image_name}", release_track)
                    new_image_version =  construct_image_name(new_registry, f"{new_repo}/{gcr_image_name}", release_version)

                # Pull the old image, tag it with the new image names, and push them to the new registry
                print(f'Key: {values_key}\nOld_image: {old_image}\nNew_image_track: {new_image_track}\nNew_image_version: {new_image_version}')
                
                docker_commands = [
                    ['docker', 'pull', old_image],
                    ['docker', 'tag', old_image, new_image_track],
                    ['docker', 'tag', old_image, new_image_version],
                    ['docker', 'push', new_image_track],
                    ['docker', 'push', new_image_version]
                ]

                for command in docker_commands:
                    result = subprocess.run(command, stdout=subprocess.PIPE)
                    if result.returncode != 0:
                        print(f'Command: {command}\nError: {result.stdout.decode("utf-8")}')
                        exit(1)
                    else:
                        print(f'Command: {command}\nSuccess: {result.stdout.decode("utf-8")}')
                
                print(f'Image: {new_image_track} and {new_image_version} pushed to {new_registry}\n')
