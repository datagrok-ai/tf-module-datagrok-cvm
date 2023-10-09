#!/bin/bash
# shellcheck disable=SC2154
echo "ECS_CLUSTER=${ecs_cluster_name}" >>/etc/ecs/ecs.config

if [[ ${gpu_enabled} == "true" ]]; then
    echo "ECS_ENABLE_GPU_SUPPORT=true" >>/etc/ecs/ecs.config
fi
