import os
import subprocess
from pathlib import Path

from kubeconfig import KubeConfig

from runner.domain import HelmRepository


class ClusterInterface:
    _global_environment_variables = {"AWS_PROFILE": "terraform", "PATH": "/usr/local/bin"}

    def setup_kubecontext(self, cluster_name, kubeconfig_file: Path):
        os.remove(kubeconfig_file)
        subprocess.run(
            f"aws eks update-kubeconfig --name {cluster_name} --kubeconfig {kubeconfig_file.absolute()}",
            env=self._global_environment_variables, shell=True, capture_output=True
        )
        conf = KubeConfig(str(kubeconfig_file))
        conf.rename_context(conf.current_context(), cluster_name)
        conf.use_context(cluster_name)

    def install_chart(self, branch, kubeconfig: Path, helm_repository: HelmRepository, helm_version: str,
                      service_account_role_arn: str, extra_values_yaml: Path):
        authconfig = helm_repository.get_authconfig()
        release_name = f"aws-efs-csi-driver-{branch}"
        subprocess.run(
            f"echo $HELM_PASSWORD | helm registry login --username $HELM_USER --password-stdin "
            f"{helm_repository.get_ecr_url()} && helm upgrade --kubeconfig {kubeconfig.absolute()} --kube-context aws-efs-csi-driver-test "
            f"--install {release_name[:62]} --namespace {branch} --create-namespace --version {helm_version} "
            f"--set 'node.serviceAccount.annotations.eks\.amazonaws\.com/role-arn={service_account_role_arn}' "
            f"--set 'controller.serviceAccount.annotations.eks\.amazonaws\.com/role-arn={service_account_role_arn}' "
            f"--set replicaCount=1 -f \"{extra_values_yaml.absolute()}\" "
            f"oci://{helm_repository.get_ecr_url()}aws-efs-csi-driver",
            shell=True, env={
                "HELM_USER": authconfig['username'],
                "HELM_PASSWORD": authconfig['password'],
            } | self._global_environment_variables
        )

    def uninstall_chart(self, branch, kubeconfig: Path):
        subprocess.run(
            f"helm --kubeconfig \"{kubeconfig.absolute()}\" --kube-context aws-efs-csi-driver-test "
            f"uninstall aws-efs-csi-driver-{branch} -n {branch}", shell=True,
            env=self._global_environment_variables
        )
