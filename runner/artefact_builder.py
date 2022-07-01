import abc
import subprocess
import time
from pathlib import Path

import docker
import ruamel.yaml
import yaml


class ArtefactBuilder(metaclass=abc.ABCMeta):

    @staticmethod
    def git_checkout(directory, branch):
        subprocess.run(
            f"git --git-dir \"{directory}/.git\" --work-tree \"{directory}\" checkout -fq {branch}",
            shell=True
        )


class DockerBuilder(ArtefactBuilder):
    docker_client = docker.from_env()

    def build(self, branch, driver_repository_path, version, repository_url):
        self.git_checkout(driver_repository_path, branch)
        tag = f"v{version}-{branch}.{int(time.time())}"
        self.docker_client.images.build(
            path=driver_repository_path, tag=f"{repository_url}:{tag}", dockerfile="Dockerfile",
            rm=True, buildargs={
                "TARGETARCH": "amd64",
                "TARGETOS": "linux"
            }
        )
        self.git_checkout(driver_repository_path, "master")
        return tag


class HelmBuilder(ArtefactBuilder):
    _yaml_client = ruamel.yaml.YAML()

    def build(self, branch, helm_chart_path, image_name, image_tag):
        driver_repository_path = Path(helm_chart_path, "..", "..")
        self.git_checkout(driver_repository_path, branch)
        # Update the chart metadata and values to pick up the new versions
        with open(Path(helm_chart_path, "Chart.yaml"), "r") as fp:
            chart = yaml.safe_load(fp)
            version = f"{chart['version']}+{branch}.{int(time.time())}"
            chart_name = chart["name"]
        with open(Path(helm_chart_path, "values.yaml"), "r") as fp:
            values = self._yaml_client.load(fp)
            values["image"]["repository"] = image_name
            values["image"]["tag"] = image_tag
        with open(Path(helm_chart_path, "values.yaml"), "w") as fp:
            self._yaml_client.dump(values, fp)
        # Package up the file
        output_path = Path(helm_chart_path, "..").absolute()
        subprocess.run(
            f"helm package --app-version {image_tag[1:]} --version {version} -d \"{output_path}\" \"{helm_chart_path}\"",
            shell=True
        )
        self.git_checkout(driver_repository_path, "master")
        return Path(output_path, f"{chart_name}-{version}.tgz"), version

    @staticmethod
    def get_appVersion(helm_chart_path):
        with open(Path(helm_chart_path, "Chart.yaml")) as fp:
            chart = yaml.safe_load(fp)
            return chart["appVersion"]
