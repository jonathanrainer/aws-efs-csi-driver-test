import os
import sys
from pathlib import Path

from artefact_builder import DockerBuilder, HelmBuilder
from cluster_interface import ClusterInterface
from infrastructure_provisioner import InfrastructureProvisioner


class EnvironmentProvisioner:
    _kubeconfig_file = None
    _driver_repository_path = ""

    _helm_builder = HelmBuilder()
    _infrastructure_provisioner = InfrastructureProvisioner()
    _cluster_interface = ClusterInterface()
    _docker_builder = DockerBuilder()

    def __init__(self, kubeconfig, driver_repository_path) -> None:
        self._kubeconfig_file = Path(kubeconfig)
        self._driver_repository_path = driver_repository_path

    def setup_test_environment(self, branch):
        # Setup a cluster if one doesn't already exist/restore a cluster to a known state
        env = self._infrastructure_provisioner.ensure_base_infrastructure(branch)
        # Set the Kubeconfig correctly, so it's easy to access the cluster
        self._cluster_interface.setup_kubecontext(env.get_cluster().get_name(), self._kubeconfig_file)

        # Build the driver Docker image and push to ECR
        helm_chart_path = Path(self._driver_repository_path, "charts", "aws-efs-csi-driver")
        tag = self._docker_builder.build(branch, self._driver_repository_path,
                                         self._helm_builder.get_appVersion(helm_chart_path),
                                         env.get_docker_repository().get_repository_url())
        env.get_docker_repository().push_image(tag)

        # Build the Helm Chart and push to ECR
        packaged_helm_chart_path, version = self._helm_builder.build(branch, helm_chart_path,
                                                                     env.get_docker_repository().get_repository_url(),
                                                                     tag)
        env.get_helm_repository().push_chart(packaged_helm_chart_path)
        os.remove(packaged_helm_chart_path)

        # Install the Helm Chart into the cluster
        self._cluster_interface.install_chart(
            branch, self._kubeconfig_file, env.get_helm_repository(), version,
            self._infrastructure_provisioner.get_terraform_output("service_account_role_arn", "raw")
        )

        # Install the Text Fixtures on top (EFS etc.)
        self._infrastructure_provisioner.ensure_test_fixtures(env.get_cluster().serialise_to_json(),
                                                              env.get_vpc().get_id(), branch)

    def destroy_test_environment(self, branch):
        cluster_json = self._infrastructure_provisioner.get_terraform_output("cluster", "json")
        vpc_id = self._infrastructure_provisioner.get_terraform_output("vpc_id", "json")
        self._infrastructure_provisioner.destroy_test_fixtures(cluster_json, vpc_id, branch)
        self._infrastructure_provisioner.destroy_base_infrastructure()


if __name__ == "__main__":
    branch_name = sys.argv[1]
    kubeconfig_file = sys.argv[2]
    driver_repository_path = sys.argv[3]

    ep = EnvironmentProvisioner(kubeconfig_file, driver_repository_path)
    ep.setup_test_environment(branch_name)