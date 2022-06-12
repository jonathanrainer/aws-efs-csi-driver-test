import abc
import base64
import json
import subprocess
from pathlib import Path

import boto3
import docker

from runner.artefact_builder import HelmBuilder


class Cluster:
    _name = ""
    _security_group_id = ""
    _endpoint = ""
    _ca_cert = ""

    def __init__(self, name, security_group_id, endpoint, ca_cert):
        self._name = name
        self._security_group_id = security_group_id
        self._endpoint = endpoint
        self._ca_cert = ca_cert

    def get_name(self):
        return self._name

    def serialise_to_json(self):
        return json.dumps({
            "name": self._name,
            "security_group_id": self._security_group_id,
            "endpoint": self._endpoint,
            "ca_cert": self._ca_cert
        })


class Repository(metaclass=abc.ABCMeta):
    _url = None

    def __init__(self, url):
        self._url = url
        session = boto3.Session(profile_name="terraform")
        self._ecr_client = session.client("ecr")

    def get_repository_url(self):
        return self._url

    def get_ecr_repository_id(self):
        return [
            repo["registryId"] for repo in self._ecr_client.describe_repositories(
            )["repositories"] if repo["repositoryUri"] == self._url
        ][0]

    def get_authconfig(self):
        authorisation_token = self._ecr_client.get_authorization_token(
            registryIds=[
                self.get_ecr_repository_id()
            ]
        )
        user_password_pair = (base64.b64decode(authorisation_token['authorizationData'][0]['authorizationToken'])) \
            .decode("utf-8") \
            .split(':')
        return {"username": user_password_pair[0], "password": user_password_pair[-1]}


class HelmRepository(Repository):

    def __init__(self, url):
        super().__init__(url)

    def get_auth_url(self):
        return self.get_repository_url()[:self.get_repository_url().rfind('/')]

    def get_ecr_url(self):
        return self.get_auth_url() + "/"

    def push_chart(self, packaged_helm_chart):
        authconfig = self.get_authconfig()
        repo_url = f"oci://{self.get_ecr_url()}"
        subprocess.run(
            f"echo $HELM_PASSWORD | helm registry login --username $HELM_USER --password-stdin "
            f"{self.get_ecr_url()} && helm push \"{packaged_helm_chart}\" {repo_url}",
            shell=True,  env={
                "HELM_USER": authconfig['username'],
                "HELM_PASSWORD": authconfig['password']
            }
        )


class DockerRepository(Repository):
    _docker_client = docker.from_env()

    def __init__(self, url):
        super().__init__(url)

    def push_image(self, tag):
        authconfig = self.get_authconfig()
        self._docker_client.images.push(
            self._url, tag, auth_config=authconfig
        )


class VirtualPrivateCloud:
    _id = ""

    def __init__(self, vpc_id):
        self._id = vpc_id

    def get_id(self):
        return self._id


class Environment:
    _cluster = None
    _vpc = None
    _docker_repository = None
    _helm_repository = None

    def __init__(self, cluster, vpc, docker_repository, helm_repository) -> None:
        self._cluster = cluster
        self._vpc = vpc
        self._docker_repository = docker_repository
        self._helm_repository = helm_repository

    def get_cluster(self) -> Cluster:
        return self._cluster

    def get_docker_repository(self) -> DockerRepository:
        return self._docker_repository

    def get_helm_repository(self) -> HelmRepository:
        return self._helm_repository

    def get_vpc(self) -> VirtualPrivateCloud:
        return self._vpc


if __name__ == "__main__":
    hr = HelmRepository("750819418690.dkr.ecr.us-east-2.amazonaws.com/aws-efs-csi-driver")
    hr.push_chart(Path("/Users/jonathanrainer/Documents/Personal Development/aws-efs-csi-driver/charts/aws-efs-csi-driver-2.2.6+support-tags-with-spaces.1655020303.tgz"))
