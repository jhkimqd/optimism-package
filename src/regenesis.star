ARTIFACTS = [
    {
        "name": "run-modify-config.sh",
        "file": "./run-modify-config.sh",
    },
]

def run_regenesis(plan, deployment_output, args):
    artifact_paths = list(ARTIFACTS)
   
    artifacts = []
    for artifact_cfg in artifact_paths:
        template = read_file(src=artifact_cfg["file"])
        artifact = plan.render_templates(
            name=artifact_cfg["name"],
            config={
                artifact_cfg["name"]: struct(
                    template=template,
                    data={

                    },
                )
            },
        )
        artifacts.append(artifact)
    
    artifacts.append(deployment_output)

    # Create helper service 
    regenesis_service_name = "regenesis"
    plan.add_service(
        name=regenesis_service_name,
        config=ServiceConfig(
            image="ubuntu",
            files={
                "/network-configs": Directory(artifact_names=artifacts),
            },
            # These two lines are only necessary to deploy to any Kubernetes environment (e.g. GKE).
            entrypoint=["bash", "-c"],
            cmd=["sleep infinity"],
            user=User(uid=0, gid=0),  # Run the container as root user.
        ),
    )

    # Extract L1 block hash and substitute into rollup config
    plan.exec(
        description="Modifying OP Rollup Config",
        service_name=regenesis_service_name,
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                "chmod +x {0} && {0}".format(
                    "./network-configs/run-modify-config.sh"
                ),
            ]
        ),
    )

    # Store CDK configs.
    plan.store_service_files(
        name="cdk-erigon-regenesis-json",
        service_name="regenesis",
        src="/network-configs/regenesis.json",
    )

    # plan.store_service_files(
    #     name="cdk-erigon-rerollup-json",
    #     service_name="regenesis",
    #     src="/network-configs/rerollup.json",
    # )