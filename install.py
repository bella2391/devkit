import os
import subprocess
from datetime import datetime

env_file = ".env"

default_user = "user"
default_user_password = default_user
default_group = "users"

if os.path.exists(env_file):
    with open(env_file, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                key, value = line.split("=", 1)
                os.environ[key] = value

docker_user = os.environ.get("DOCKER_USER", default_user)
docker_user_passwd = os.environ.get("DOCKER_USER_PASSWD", default_user_password)
docker_group = os.environ.get("DOCKER_GROUP", default_group)

if not os.path.exists(env_file) or \
   "DOCKER_USER" not in open(env_file).read() or \
   "DOCKER_USER_PASSWD" not in open(env_file).read() or \
   "DOCKER_GROUP" not in open(env_file).read():

    docker_user = input(f"Enter Docker username (default: {default_user}): ") or default_user
    docker_user_passwd = input(f"Enter Docker user password (default: {default_user}): ") or default_user_password
    docker_group = input(f"Enter Docker group (default: {default_group}): ") or default_group

    with open(env_file, "w") as f:
        f.write(f"DOCKER_USER={docker_user}\n")
        f.write(f"DOCKER_USER_PASSWD={docker_user_passwd}\n")
        f.write(f"DOCKER_GROUP={docker_group}\n")

    print(f"Environment variables saved to {env_file}")

def run_docker_commands():
    """Dockerコマンドを実行する関数"""

    container = f"devkit_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

    build_confirmation = input(f"Dockerイメージ '{container}' をビルドしますか？ [Y/N]: ").upper()
    if build_confirmation == "Y":
        try:
            subprocess.run([
                "docker", "build",
                "--build-arg", f"DOCKER_USER={docker_user}",
                "--build-arg", f"DOCKER_USER_PASSWD={docker_user_passwd}",
                "--build-arg", f"DOCKER_GROUP={docker_group}",
                "-t", container, "."
            ], check=True)
            print(f"Dockerイメージ '{container}' のビルドが完了しました。")
        except subprocess.CalledProcessError as e:
            print(f"エラーが発生しました: {e}")
            return
    else:
        print(f"Dockerイメージ '{container}' のビルドをスキップします。")

    export_confirmation = input(f"WSLでイメージ '{container}' をインポートするためのtarファイルを作成しますか？ [Y/N]: ").upper()
    if export_confirmation == "Y":
        try:
            subprocess.run(["docker", "run", "--name", container, "-e", f"DOCKER_USER={docker_user}", "-e", f"DOCKER_USER_PASSWD={docker_user_passwd}", "-e", f"DOCKER_GROUP={docker_group}", f"{container}:latest"], check=True)
            print(f"コンテナ '{container}' が起動しました。")

            export_path = input("tarファイルの出力ディレクトリを指定してください: ").strip()

            # 拡張子の判定
            _, ext = os.path.splitext(export_path)

            if ext.lower() == ".tar":
                # もしユーザーが *.tar を指定していたら、そのままファイルとして扱う
                tar_file_path = export_path
                parent_dir = os.path.dirname(os.path.abspath(export_path)) or os.getcwd()
                print(f"指定されたファイルに保存します: {tar_file_path}")
            else:
                # ディレクトリの判定
                if export_path in ["./", "."]:
                    export_path = os.getcwd()  # カレントディレクトリ
                    print(f"カレントディレクトリ ({export_path}) に保存します。")
                elif os.path.isabs(export_path):
                    print(f"絶対パス（{export_path}）に保存します。")
                else:
                    export_path = os.path.abspath(export_path)  # 相対パスを絶対パスに変換
                    print(f"相対パス（{export_path}）に保存します。")

                tar_file_path = os.path.join(export_path, f"{container}.tar")  # ファイル名を決定

            # docker export の実行
            subprocess.run(["docker", "export", "-o", tar_file_path, container], check=True)
            print(f"tarファイルを {tar_file_path} に作成しました。")

            subprocess.run(["docker", "container", "rm", container], check=True)
            print(f"コンテナ '{container}' を削除しました。")

        except subprocess.CalledProcessError as e:
            print(f"エラーが発生しました: {e}")
            return
    else:
        print(f"tarファイルの作成をスキップします。")

if __name__ == "__main__":
    run_docker_commands()

