import os
import subprocess
import argparse
import threading
import itertools
import time
from datetime import datetime

env_file = ".env"

def input_with_default(prompt, default):
    user_input = input(f"{prompt} (デフォルト: {default}): ").strip()
    return user_input if user_input else default

def load_env():
    """ .env ファイルを読み込む """
    env_vars = {}
    if os.path.exists(env_file):
        with open(env_file, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    env_vars[key] = value
    return env_vars

def prompt_env(env_vars):
    default_user = "user"
    default_user_password = default_user
    default_group = "users"

    """ 環境変数を対話形式で取得 """
    env_vars["DOCKER_USER"] = input(f"Enter Docker username (default: {env_vars.get('DOCKER_USER', default_user)}): ") or env_vars.get("DOCKER_USER", default_user)
    env_vars["DOCKER_USER_PASSWD"] = input(f"Enter Docker user password (default: {env_vars.get('DOCKER_USER_PASSWD', default_user_password)}): ") or env_vars.get("DOCKER_USER_PASSWD", default_user_password)
    env_vars["DOCKER_GROUP"] = input(f"Enter Docker group (default: {env_vars.get('DOCKER_GROUP', default_group)}): ") or env_vars.get("DOCKER_GROUP", default_group)

    with open(env_file, "w") as f:
        for key, value in env_vars.items():
            f.write(f"{key}={value}\n")

    print(f"Environment variables saved to {env_file}")
    return env_vars

def import_module():
    print("ビルドに必要なファイルをダウンロードします。")
    try:
        subprocess.run(["git", "submodule", "update", "--init", "--recursive"], check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"エラーが発生しました: {e}")
    return False

def build_docker_image(env_vars, debug_mode=False):
    """ Docker イメージをビルド """
    container_name = f"devkit_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

    build_confirmation = input_with_default(f"Dockerイメージ '{container_name}' をビルドしますか？", "Y").upper()
    if build_confirmation == "Y":
        module_check = import_module()
        if not module_check:
            return

        # generate Dockerfile
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

        try:
            subprocess.run([
                "docker", "build",
                "--build-arg", f"DOCKER_USER={env_vars['DOCKER_USER']}",
                "--build-arg", f"DOCKER_USER_PASSWD={env_vars['DOCKER_USER_PASSWD']}",
                "--build-arg", f"DOCKER_GROUP={env_vars['DOCKER_GROUP']}",
                "-f", "Dockerfile.generated",
                "-t", container_name, "."
            ], check=True)
            print(f"Dockerイメージ '{container_name}' のビルドが完了しました。")
            return container_name
        except subprocess.CalledProcessError as e:
            print(f"エラーが発生しました: {e}")
        finally:
            os.remove("Dockerfile.generated")
    return None

def run_docker_container_with_tty(container_name, env_vars):
    """ Docker コンテナを実行 """
    if not container_name:
        print("コンテナ名が不明なため、実行をスキップします。")
        return

    run_confirmation = input_with_default(f"Dockerコンテナ '{container_name}' を実行しますか？", "Y").upper()
    if run_confirmation == "Y":
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
            print(f"エラーが発生しました: {e}")
    else:
        print("Dockerコンテナの実行をスキップします。")

def animated_message(stop_event):
    i = 1
    last_print_time = time.time()

    while not stop_event.is_set():
        if stop_event.is_set():
            break

        current_time = time.time()
        if current_time - last_print_time >= 1:
            print(f"\rwslファイルを作成中です {' '.join('.' * i)}", end="", flush=True)
            last_print_time = current_time
            i += 1

        time.sleep(0.1)

    print("\rwslファイルの作成が完了しました。          ")

def export_wsl(container_name, env_vars):
    """Dockerコマンドを実行する関数"""
    export_confirmation = input_with_default(f"WSLでイメージ '{container_name}' をインポートするためのwslファイルを作成しますか？", "Y").upper()
    if export_confirmation == "Y":
        subprocess.run([
            "docker", "run", "-d", "--name", container_name, "--privileged",
            "-e", f"DOCKER_USER={env_vars['DOCKER_USER']}",
            "-e", f"DOCKER_USER_PASSWD={env_vars['DOCKER_USER_PASSWD']}",
            "-e", f"DOCKER_GROUP={env_vars['DOCKER_GROUP']}",
            f"{container_name}:latest"
        ], check=True)
        print(f"コンテナ '{container_name}' が起動しました。")

        export_path = input("wslファイルの出力ディレクトリを指定してください (デフォルト: カレントディレクトリ): ").strip()
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

        print(f"wslファイルを {wsl_file_path} に作成しました。")

        exec_confirmation = input_with_default("WSLにインポートしますか？（Windows用）", "Y").upper()
        if exec_confirmation == "Y":
            print(f"{container_name}.wsl のインポートを開始します。")
            subprocess.run(["wsl", "--install", "--from-file", wsl_file_path], check=True)
        else:
            print(f"{container_name}.wsl のインポートをスキップしました。")

        remove_confirmation = input_with_default("既存のコンテナを削除しますか？", "Y").upper()
        if remove_confirmation == "Y":
            subprocess.run(["docker", "stop", container_name], check=True)
            subprocess.run(["docker", "rm", container_name], check=True)
            print(f"コンテナ '{container_name}' を削除しました。")
        else:
            print(f"コンテナ '{container_name}' の削除をスキップしました。")

        print("すべての操作が終了しました。")
    else:
        print("\nwslファイルのエクスポートを中断しました。")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Docker環境セットアップスクリプト")
    parser.add_argument("--debug", action="store_true", help="デバッグモードを有効化")
    args = parser.parse_args()

    try:
        if args.debug:
            print("=== デバッグモードが有効です。 ===")

        env_vars = load_env()
        if not env_vars:
            env_vars = prompt_env({})

        container_name = build_docker_image(env_vars, args.debug)

        if args.debug:
            run_docker_container_with_tty(container_name, env_vars)
        else:
            export_wsl(container_name, env_vars)
    except KeyboardInterrupt:
        print("\n操作を中断しました。")

