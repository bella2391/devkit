import os
import subprocess

env_file = ".env"

default_user = "user"
default_group = "users"

if not os.path.exists(env_file) or \
   "DOCKER_USER" not in open(env_file).read() or \
   "DOCKER_USER_PASSWD" not in open(env_file).read() or \
   "DOCKER_GROUP" not in open(env_file).read():

    docker_user = input(f"Enter Docker username (default: {default_user}): ") or default_user
    docker_user_passwd = input(f"Enter Docker user password (default: {default_user}): ") or default_user
    docker_group = input(f"Enter Docker group (default: {default_group}): ") or default_group

    with open(env_file, "w") as f:
        f.write(f"DOCKER_USER={docker_user}\n")
        f.write(f"DOCKER_USER_PASSWD={docker_user_passwd}\n")
        f.write(f"DOCKER_GROUP={docker_group}\n")

    print(f"Environment variables saved to {env_file}")

try:
    subprocess.run(["docker-compose", "build"], check=True)
    print("docker-compose build completed successfully.")
except subprocess.CalledProcessError as e:
    print(f"docker-compose build failed: {e}")
except FileNotFoundError:
    print("docker-compose command not found. Please install Docker Compose.")
