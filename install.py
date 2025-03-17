import os
import subprocess

env_file = ".env"

default_user = "user"
default_group = "users"
default_user_id = "1000"

if not os.path.exists(env_file) or \
   "DOCKER_USER" not in open(env_file).read() or \
   "DOCKER_GROUP" not in open(env_file).read() or \
   "DOCKER_USER_ID" not in open(env_file).read():

    docker_user = input(f"Enter Docker username (default: {default_user}): ") or default_user
    docker_group = input(f"Enter Docker group (default: {default_group}): ") or default_group
    docker_user_id = input(f"Enter Docker user ID (default: {default_user_id}): ") or default_user_id

    with open(env_file, "w") as f:
        f.write(f"DOCKER_USER={docker_user}\n")
        f.write(f"DOCKER_GROUP={docker_group}\n")
        f.write(f"DOCKER_USER_ID={docker_user_id}\n")

    print(f"Environment variables saved to {env_file}")

try:
    subprocess.run(["docker-compose", "build"], check=True)
    print("docker-compose build completed successfully.")
except subprocess.CalledProcessError as e:
    print(f"docker-compose build failed: {e}")
except FileNotFoundError:
    print("docker-compose command not found. Please install Docker Compose.")
