import json
import os
import subprocess
from pathlib import Path

from domain import Environment, Cluster, VirtualPrivateCloud, DockerRepository, HelmRepository


class InfrastructureProvisioner:
    _terraform_directory = Path(os.path.dirname(os.path.abspath(__file__)), "..", "terraform")
    _infrastructure_directory = Path(_terraform_directory, "infrastructure")
    _fixtures_directory = Path(_terraform_directory, "test-fixtures")
    _global_environment_variables = {"AWS_PROFILE": "terraform"}

    def ensure_base_infrastructure(self, branch):
        proc = subprocess.Popen(f"terraform -chdir=\"{self._infrastructure_directory}\" apply -auto-approve "
                                f"-var 'namespace={branch}'", shell=True,
                                env=self._global_environment_variables, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT)
        for line in proc.stdout:
            print(line.decode("unicode_escape"), end='')
        return Environment(
            Cluster(**json.loads(self.get_infrastructure_terraform_output("cluster", "json"))),
            VirtualPrivateCloud(self.get_infrastructure_terraform_output("vpc_id", "raw")),
            DockerRepository(self.get_infrastructure_terraform_output("docker_repository_url", "raw")),
            HelmRepository(self.get_infrastructure_terraform_output("helm_repository_url", "raw"))
        )

    def destroy_base_infrastructure(self, branch):
        proc = subprocess.Popen(f"terraform -chdir=\"{self._infrastructure_directory}\" destroy -auto-approve -var "
                                f"namespace={branch}",
                                shell=True,
                                env=self._global_environment_variables, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT)
        for line in proc.stdout:
            print(line.decode("unicode_escape"), end='')

    def ensure_test_fixtures(self, cluster_json, vpc_id, branch):
        proc = subprocess.Popen(f"terraform -chdir=\"{self._fixtures_directory}\" apply -auto-approve "
                                f"-var 'cluster={cluster_json}' -var 'vpc_id={vpc_id}' -var 'namespace={branch}'",
                                shell=True,
                                env={
                                    "AWS_PROFILE": "terraform",
                                    "TF_LOG_PROVIDER": "DEBUG"
                                }, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT)
        for line in proc.stdout:
            print(line.decode("unicode_escape"), end='')

    def destroy_test_fixtures(self, cluster_json, vpc_id, branch):
        proc = subprocess.Popen(f"terraform -chdir=\"{self._fixtures_directory}\" destroy -auto-approve "
                                f"-var 'cluster={cluster_json}' -var 'vpc_id={vpc_id}' -var 'namespace={branch}'",
                                shell=True,
                                env=self._global_environment_variables, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT)
        for line in proc.stdout:
            print(line.decode("unicode_escape"), end='')

    def get_infrastructure_terraform_output(self, output_variable_name, output_format):
        return self.get_terraform_output(self._infrastructure_directory, output_variable_name, output_format)

    def get_test_fixture_terraform_output(self, output_variable_name, output_format):
        return self.get_terraform_output(self._fixtures_directory, output_variable_name, output_format)

    def get_terraform_output(self, directory, output_variable_name, output_format):
        proc = subprocess.run(
            f"terraform -chdir=\"{directory}\" output -{output_format} {output_variable_name}",
            shell=True, env=self._global_environment_variables, capture_output=True
        )
        return proc.stdout.strip().decode("utf-8")