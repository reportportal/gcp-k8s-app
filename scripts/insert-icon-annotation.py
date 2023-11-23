import yaml

# Load the icon.yaml file and get the value
with open('assets/icon-base64.txt', 'r') as f:
    icon_data = f.read().strip()

# Load the application.yaml file
with open('scripts/application-template.yaml') as f:
    app_data = yaml.safe_load(f)

# Insert the value into the metadata.annotations field
app_data['metadata']['annotations']['kubernetes-engine.cloud.google.com/icon'] = icon_data

# Write the updated data back to application.yaml
with open('chart/reportportal-k8s-app/templates/application.yaml', 'w') as f:
    yaml.safe_dump(app_data, f)