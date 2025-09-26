#!/bin/bash

ea_update_all_repo() {
  for name in "${!EA_REP_MAP[@]}"; do
    IFS='|' read -r repo_url repo_name repo_chart repo_version <<< "${EA_REP_MAP[$name]}"
    helm repo add "$repo_name" "$repo_url"
  done
  helm repo update
}

ea_update_repo() {
  local name=$1
  if [[ ${EA_REP_MAP[$name]+exists} ]]; then
    IFS='|' read -r repo_url repo_name repo_chart repo_version <<< "${EA_REP_MAP[$name]}"
    helm repo add "$repo_name" "$repo_url"
    helm repo update
  fi
}

_ea_opt_value() {
  local value_path=$1
  local value_filename=$2
  [ -f $value_path/$value_filename.yaml ] && echo -n "-f $value_path/$value_filename.yaml "
  [ -f $value_path/$value_filename-$EA_PLATFORM.yaml ] && echo -n "-f $value_path/$value_filename-$EA_PLATFORM.yaml "
}

# eg) -f values/eva-agent/values-aws.yaml
ea_opt_value() {
  _ea_opt_value $EA_VALUE_ROOT/$1 values
}

ea_opt_post_renderer() {
  local value_path=$EA_VALUE_ROOT/$1
  local post_renderer_sh=$value_path/post-renderer.sh
  [ -f $post_renderer_sh ] && echo "--post-renderer $post_renderer_sh "
}

# eg) secret values file for eva-agent
# cp ./secrets.tpl/secret-values-eva-agent.yaml.tpl ./.secret-values-eva-agent.yaml
# vi ./.secret-values-eva-agent.yaml
# " -f ./.secret-values-eva-agent.yaml " opt will be added if the file exists
ea_opt_secret() {
  local name=$1
  local secret_values_file=./.secret-values-$name.yaml
  [ -f $secret_values_file ] && echo -n "-f $secret_values_file "
}

_aws_docker_login() {
  AWS_ECR_REGION=ap-northeast-2
  AWS_ECR_HOST=339713051385.dkr.ecr.${AWS_ECR_REGION}.amazonaws.com

  ( \
    aws ecr get-login-password --profile default \
    | docker login --username AWS --password-stdin $AWS_ECR_HOST \
  ) \
  || \
  ( \
    printf "AWS ECR login with default profile failed.. try..\n"
    printf "Enter AWS_ACCESS_KEY_ID: "
    read -s AWS_ACCESS_KEY_ID
    echo
    printf "Enter AWS_SECRET_ACCESS_KEY: "
    read -s AWS_SECRET_ACCESS_KEY
    echo
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
    aws ecr get-login-password --region $AWS_ECR_REGION \
    | docker login --username AWS --password-stdin $AWS_ECR_HOST \
  )
}

_ea_command() {
  local cmd=$1
  local name=$2
  shift 2  # $1, $2 제거

  if [[ ! -d "$EA_VALUE_ROOT" ]]; then
    echo ERROR: No directory on EA_VALUE_ROOT - $EA_VALUE_ROOT
    return
  fi
  if [[ ! -d "$EA_VALUE_ROOT/$name" ]]; then
    echo ERROR: No value directory - $EA_VALUE_ROOT/$name
    return
  fi

  # app specific options
  local app_spec_opt=
  local values_file=
  if [[ "$name" == "eva-agent" ]]; then
    local docker_config_file="$HOME/.docker/config.json"
    _aws_docker_login
    if [[ ! -f "$docker_config_file" ]]; then
      echo "AWS ECR login failed - ECR pull needed"
      return 1
    fi

    # make temp value file
    values_file="$docker_config_file-values.yaml"
    cat > "$values_file" << EOF
dockerConfig:
  json: $(cat "$docker_config_file" | base64 -w0)
EOF
    #app_spec_opt="--set dockerConfig.json=\"$(cat "$docker_config_file" | base64 -w0)\""
    app_spec_opt="-f $values_file"
  fi

  ea_update_repo $name

  local opt_value=$( ea_opt_value $name )
  local opt_secret=$( ea_opt_secret $name )
  local opt_post_renderer=$( ea_opt_post_renderer $name )

  if [[ ${EA_REP_MAP[$name]+exists} ]]; then
    IFS='|' read -r repo_url repo_name repo_chart repo_version <<< "${EA_REP_MAP[$name]}"
    echo === $cmd from repo chart
    echo COMMAND] helm $cmd $name $repo_chart --version="$repo_version" -n $EA_NS $opt_value $opt_secret $app_spec_opt $@ $opt_post_renderer
    helm $cmd $name $repo_chart --version="$repo_version" -n $EA_NS $opt_value $opt_secret $app_spec_opt $@ $opt_post_renderer
  else
    if [[ -d "$EA_CHART_ROOT/$name" ]]; then
      echo === $cmd from local chart
      echo COMMAND] helm $cmd $name $EA_CHART_ROOT/$name -n $EA_NS $opt_value $opt_secret $app_spec_opt $@ $opt_post_renderer
      helm $cmd $name $EA_CHART_ROOT/$name -n $EA_NS $opt_value $opt_secret $app_spec_opt $@ $opt_post_renderer
    else
      echo ERROR: Chart $name not found - $EA_CHART_ROOT/$name - no repository nor local
    fi
  fi

  # clean up
  [[ -e  "$values_file" ]] && rm -f "$values_file"
}

ea_template() {
  _ea_command template $@
}

ea_install() {
  _ea_command install $@
}

ea_uninstall() {
  helm uninstall $1 -n $EA_NS
}

ea_upgrade() {
  _ea_command upgrade $@
}

ea_get_all() {
  kubectl get all,pvc -n $EA_NS
  echo
  # pv
  kubectl get pv | egrep "^NAME| $EA_NS/"
}

_ea_delete_all_pv() {
  echo -n "CAUTION: It removes PV used as qdrant persistent storage permanently. Are you sure to proceed? (y/n) "
  read YN
  if [[ $YN == "y" || $YN == "Y" ]]; then
    echo "Deleting PVC: eva-agent-ollama"
    kubectl delete pvc eva-agent-ollama -n $EA_NS
    echo "Deleting PVC: eva-agent-qdrant"
    kubectl delete pvc -l app.kubernetes.io/instance=eva-agent-qdrant -n $EA_NS
    echo $( ea_get_all_pv ) | awk '{print $1}' | while read pv_name; do
      echo "Deleting PV: $pv_name"
      kubectl delete pv "$pv_name"
    done
  else
    echo "Skip deleting PV"
  fi
}
