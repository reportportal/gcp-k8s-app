import yaml
import subprocess
import argparse
import yaml

# Create the parser
parser = argparse.ArgumentParser(description="Script for publishing used chart images to GCR")

# Add the arguments
parser.add_argument('--values-path', type=str, required=True, help='Path to the chart values.yaml file')
parser.add_argument('--release-track' , type=str, required=True, help='Release track')
parser.add_argument('--release-version', type=str, required=True, help='Release version')
parser.add_argument('--primary-service', type=str, required=False, default='serviceapi', help='Primary service')
parser.add_argument('--old-repo', type=str, required=False, default='reportportal', help='Old repository')
parser.add_argument('--new-registry', type=str, required=False, default='gcr.io', help='New registry')
parser.add_argument('--new-repo', type=str, required=False, default='epam-mp-rp/reportportal', help='New repository with registry')

# Parse the arguments
args = parser.parse_args()

# Define the new registry
values_file_path = args.values_path
release_track = args.release_track
release_version = args.release_version
primary_image_service = args.primary_service
old_repo = args.old_repo
new_registry = args.new_registry
new_repo = args.new_repo

# Load the schema.yaml file for getting the image names for gcr.io
with open('schema.yaml', 'r') as file:
    schema_file = yaml.safe_load(file)

# Load the values.yaml file for getting the image repository and tag
with open(values_file_path, 'r') as file:
    values_file = yaml.safe_load(file)

# Iterate over the images in schema.yaml
for gcr_image_name, value in schema_file['x-google-marketplace']['images'].items():
    # Get the repository and tag
    properties = value['properties']
    keys = list (properties.keys())
    chart_value = keys[0].split('.')[1]

    for values_key, value in values_file.items():
        if values_key == chart_value:
            # Get the repository and tag
            if isinstance(value, dict) and 'repository' in value:
                repository = value['repository']
                tag = value['tag']

                # Construct the old and new image names
                if values_key == primary_image_service:
                    old_image = f'{repository}:{tag}'
                    new_repository = f'{new_registry}/{new_repo}'
                    new_image_track = f'{new_repository}:{release_track}'
                    new_image_version = f'{new_repository}:{release_version}'
                else:
                    old_image = f'{repository}:{tag}'
                    new_repository = f'{new_registry}/{new_repo}/{gcr_image_name}'
                    new_image_track = f'{new_repository}:{release_track}'
                    new_image_version = f'{new_repository}:{release_version}'

                # Pull the old image, tag it with the new image names, and push them to the new registry
                print(f'Key: {values_key}\nOld_image: {old_image}\nNew_image_track: {new_image_track}\nNew_image_version: {new_image_version}')
                subprocess.run(['docker', 'pull', old_image])
                subprocess.run(['docker', 'tag', old_image, new_image_track])
                subprocess.run(['docker', 'tag', old_image, new_image_version])
                subprocess.run(['docker', 'push', new_image_track])
                subprocess.run(['docker', 'push', new_image_version])
                print(f'Image: {new_image_track} and {new_image_version} pushed to {new_registry}\n')