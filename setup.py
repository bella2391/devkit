import os
import subprocess
import argparse
import threading
import itertools
import time
from datetime import datetime
import sys

env_file = ".env"

def input_with_default(prompt, default, force_default=False):
    if force_default:
        return default
    user_input = input(f"{prompt} (default: {default}): ").strip().lower()
    return user_input if user_input else default

def load_env():
    env_vars = {}
    if os.path.exists(env_file):
        with open(env_file, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    env_vars[key] = value
    return env_vars

def prompt_env(env_vars, force_default=False):
    default_user = "user"
    default_user_password = default_user
    default_group = "users"

    env_vars["DOCKER_USER"] = input_with_default("Enter Docker username", env_vars.get("DOCKER_USER") or default_user, force_default)
    env_vars["DOCKER_USER_PASSWD"] = input_with_default("Enter Docker user password", env_vars.get("DOCKER_USER_PASSWD") or default_user_password, force_default)
    env_vars["DOCKER_GROUP"] = input_with_default("Enter Docker group", env_vars.get("DOCKER_GROUP") or default_group, force_default)

    with open(env_file, "w") as f:
        for key, value in env_vars.items():
            f.write(f"{key}={value}\n")

    print(f"Environment variables saved to {env_file}")
    return env_vars

def ensure_env_vars(force_default=False):
    env_vars = load_env()
    if not env_vars:
        env_vars = prompt_env(env_vars, force_default)
    return env_vars

def import_module():
    print("Downloading files for build...")
    try:
        subprocess.run(["git", "submodule", "update", "--init", "--recursive"], check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")
    return False

def build_docker_image(env_vars, debug_mode=False, no_cache=False, force_default=False):
    container_name = f"devkit_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

    build_confirmation = input_with_default(f"Do you build image? (name: '{container_name}')", "y", force_default).lower()
    if build_confirmation == "y":
        module_check = import_module()
        if not module_check:
            return

        with open("Dockerfile", "r") as f:
            dockerfile_content = f.read()

        if debug_mode:
            dockerfile_content += r"""
USER root

RUN mkdir -p /etc/systemd/system/getty@tty1.service.d && \
    echo "[Service]\nExecStart=\nExecStart=-/sbin/agetty --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/override.conf

RUN pacman -Sy --noconfirm systemd-sysvcompat

ENV container=docker

STOPSIGNAL SIGRTMIN+3
CMD ["/usr/lib/systemd/systemd"]
"""

        with open("Dockerfile.generated", "w") as f:
            f.write(dockerfile_content)

        docker_build_command = [
                "docker", "build",
                "--build-arg", f"DOCKER_USER={env_vars['DOCKER_USER']}",
                "--build-arg", f"DOCKER_USER_PASSWD={env_vars['DOCKER_USER_PASSWD']}",
                "--build-arg", f"DOCKER_GROUP={env_vars['DOCKER_GROUP']}",
                "-f", "Dockerfile.generated",
                "-t", container_name, "."
        ]

        if no_cache:
            print("Detected using no-cache flag.")
            docker_build_command.append("--no-cache")

        try:
            print("Starting build image...")
            subprocess.run(docker_build_command, check=True)
            print(f"Completely build image: '{container_name}' done.")
            return container_name
        except subprocess.CalledProcessError as e:
            if "connect" in str(e):
                print(f"Failed to connect docker engine.\nPlease check whether docker engine starting or not.")
                exit(1)
            else:
                print(f"An error occurred: {e}")
                exit(1)
        finally:
            os.remove("Dockerfile.generated")
    return None

def run_docker_container_with_tty(container_name, env_vars, force_default=False):
    if not container_name:
        print("Running container skipped. (detected an unamed container name)")
        return

    run_confirmation = input_with_default(f"Do you run docker container? (name: '{container_name})", "y", force_default).lower()
    if run_confirmation == "y":
        try:
            subprocess.run([
                "docker", "run", "--rm", "--privileged",
                "-e", f"DOCKER_USER={env_vars['DOCKER_USER']}",
                "-e", f"DOCKER_USER_PASSWD={env_vars['DOCKER_USER_PASSWD']}",
                "-e", f"DOCKER_GROUP={env_vars['DOCKER_GROUP']}",
                "-it",
                container_name
            ], check=True)
        except subprocess.CalledProcessError as e:
            print(f"An error occurred: {e}")
    else:
        print("Running container skipped.")

def animated_message(stop_event):
    i = 1
    last_print_time = time.time()

    while not stop_event.is_set():
        if stop_event.is_set():
            break

        current_time = time.time()
        if current_time - last_print_time >= 1:
            print(f"\rMaking wsl file {' '.join('.' * i)}", end="", flush=True)
            last_print_time = current_time
            i += 1
            if i > 5:
                i = 1

        time.sleep(0.1)

    print("\rMaking wsl file done.          ")

def export_wsl(container_name, env_vars, force_default=False):
    export_confirmation = input_with_default(f"Do you make wsl file in order to import into wsl? (name: '{container_name}')", "y", force_default).lower()
    if export_confirmation == "y":
        subprocess.run([
            "docker", "run", "-d", "--name", container_name, "--privileged",
            "-e", f"DOCKER_USER={env_vars['DOCKER_USER']}",
            "-e", f"DOCKER_USER_PASSWD={env_vars['DOCKER_USER_PASSWD']}",
            "-e", f"DOCKER_GROUP={env_vars['DOCKER_GROUP']}",
            f"{container_name}:latest"
        ], check=True)
        print(f"Starting container. (name: '{container_name}')")

        export_path = input("Enter output directory for wsl file (default: current directory): ").strip()
        if not export_path:
            export_path = os.getcwd()

        wsl_file_path = os.path.join(export_path, f"{container_name}.wsl")

        stop_event = threading.Event()
        animation_thread = threading.Thread(target=animated_message, args=(stop_event,))
        animation_thread.start()

        try:
            subprocess.run(["docker", "export", "-o", wsl_file_path, container_name], check=True)
        finally:
            stop_event.set()
            animation_thread.join()

        print(f"Placed at '{wsl_file_path}'.")

        exec_confirmation = input_with_default("Do you import wsl file into wsl? (for Windows)", "y", force_default).lower()
        if exec_confirmation == "y":
            print(f"Starting import '{container_name}'.")
            subprocess.run(["wsl", "--install", "--from-file", wsl_file_path], check=True)
        else:
            print(f"Import of '{container_name}.wsl' skipped.")

        rm_container_confirmation = input_with_default("Do you delete current working container?", "y", force_default).lower()
        if rm_container_confirmation == "y":
            subprocess.run(["docker", "stop", container_name], check=True)
            subprocess.run(["docker", "rm", container_name], check=True)
            print(f"Container deleted. (name: '{container_name}')")
            rm_image_confirmation = input_with_default("Do you also delete current working image?", "y", force_default).lower()
            if rm_image_confirmation == "y":
                subprocess.run(["docker", "rmi", container_name], check=True)
                print(f"Image deleted. (name: '{container_name}')")
            else:
                print(f"Deletion of image skipped. (name: '{container_name}')")
        else:
            print(f"Deletion of container skipped. (name: '{container_name}')")

        rm_wsl_file_confirmation = input_with_default(f"Do you delete wsl file? (name: '{container_name}.wsl')", "y", force_default).lower()

        if rm_wsl_file_confirmation == "y":
            os.remove(wsl_file_path)
        else:
            print(f"Deletion of '{container_name}.wsl' skipped.")

        print("All operation done.")
    else:
        print("\nOperation of exporting wsl file is canceled.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script for setup of WSL environment with docker")
    parser.add_argument("-i", "--install", action="store_true", help="Install: Build & Export *.wsl & Import into WSL")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug mode: Build & Run container & Enter it with tty")
    parser.add_argument("--no-cache", action="store_true", help="Build with no cache")
    parser.add_argument("-y", action="store_true", help="Response by default value for all prompts")
    parser.add_argument("--set-env", action="store_true", help="Set environment variable, saving into .env")
    args = parser.parse_args()

    try:
        if args.debug:
            print("=== Enabled Debug Mode ===")

        if len(sys.argv) == 1:
            parser.print_help()
        elif args.set_env:
            env_vars = load_env()
            if env_vars:
                set_again_confirmation = input_with_default(f"Detected .env in current directory.\nDo you try to set again? (require deleting .env)", "y", args.y).lower()
                if set_again_confirmation == "y":
                    os.remove(".env")
                    env_vars = prompt_env({}, args.y)
                else:
                    print("Setting environment variables skipped.") 
            else:
                env_vars = prompt_env({})
        elif args.debug:
            env_vars = ensure_env_vars(args.y)
            container_name = build_docker_image(env_vars, args.debug, args.no_cache, args.y)
            run_docker_container_with_tty(container_name, env_vars, args.y)
        elif args.install:
            env_vars = ensure_env_vars(args.y)
            container_name = build_docker_image(env_vars, args.debug, args.no_cache, args.y)
            export_wsl(container_name, env_vars, args.y)
    except KeyboardInterrupt:
        print("\nOperation is canceled.")

