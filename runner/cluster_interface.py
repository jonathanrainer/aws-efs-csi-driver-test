import os
import subprocess
from pathlib import Path

from kubeconfig import KubeConfig

from runner.domain import HelmRepository


class ClusterInterface:
    _global_environment_variables = {"AWS_PROFILE": "terraform"}

    def setup_kubecontext(self, cluster_name, kubeconfig_file: Path):
        os.remove(kubeconfig_file)
        subprocess.run(
            f"aws eks update-kubeconfig --name {cluster_name} --kubeconfig {kubeconfig_file.absolute()}",
            env=self._global_environment_variables, shell=True, capture_output=True
        )
        conf = KubeConfig(str(kubeconfig_file))
        conf.rename_context(conf.current_context(), cluster_name)
        conf.use_context(cluster_name)

    @staticmethod
    def install_chart(branch, kubeconfig: Path, helm_repository: HelmRepository, helm_version: str, service_account_role_arn: str):
        helm_repository.authenticate_to_registry()
        subprocess.run(
            f"helm upgrade --kubeconfig {kubeconfig.absolute()} --kube-context aws-efs-csi-driver-test "
            f"--install aws-efs-csi-driver-{branch} --namespace {branch} --create-namespace --version {helm_version} "
            f"--set 'node.serviceAccount.annotations.eks\.amazonaws\.com/role-arn={service_account_role_arn}' "
            f"--set 'controller.serviceAccount.annotations.eks\.amazonaws\.com/role-arn={service_account_role_arn}' "
            f"oci://{helm_repository.get_ecr_url()}aws-efs-csi-driver",
            shell=True
        )
