#!/bin/bash

CREATE_INFRA=0
CREATE_KEYBASED=0
CREATE_TIMEBASED=0
TABLE_NAME=""
NAMESPACE="grafana-pusher"
PV=0
BASE_URL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      BASE_URL="$2"
      shift ; shift
      ;;
    --table)
      TABLE_NAME="$2"
      shift ; shift
      ;;
    ---namespace)
      NAMESPACE="$2"
      shift ; shift
      ;;
    ---pv)
      PV="$2"
      shift ; shift
      ;;
    --create-infra)
      CREATE_INFRA=1
      shift
      ;;
    --create-keybased)
      CREATE_KEYBASED=1
      shift
      ;;
    --create-timebased)
      CREATE_TIMEBASED=1
      shift
      ;;
    -h|--help)
        CREATE_INFRA=0
        CREATE_KEYBASED=0
        CREATE_TIMEBASED=0
      shift
      ;;
  esac
done

echo_help () {
    echo "Usage: ./deployer.sh [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  --create-infra            Prepare DB, Management Infrastructure"
    echo "  --create-keybased         Create a key-based api endpoint"
    echo "  --create-timebased        Create a time-based api endpoint"
    echo "Options:"
    echo "  For infra:"
    echo "  --base-url <BASEURL>      Specify the base-url for all ingress (required)"
    echo "  --namespace <NAMESPACE>   Specify namespace to use"
    echo "  --pv <PV-NAME>            Specify a volume for the pvc, if not set"
    echo "                            no pv will be specified, but a generic pvc"
    echo "                            will be created"
    echo "  For api endpoints:"
    echo "  --table <TABLENAME>       Specify table-name (required)"
    echo ""
    exit 0
}

if [ $CREATE_INFRA -eq 1 ] ; then

    # exit if not all required arguments are passed
    if [ $BASE_URL -eq 0 ] ; then
        echo "ERROR: base-url is required!!"
        echo_help
        exit 1
    fi

    echo "Generating keys..."
    MARIA_PW=$(date | md5sum | awk '{print $1}')
    MARIA_PW_64=$(echo -n $MARIA_PW | base64)
    MARIA_ROOT_PW=$(date | md5sum | awk '{print $1}')
    MARIA_ROOT_PW_64=$(echo -n $MARIA_ROOT_PW | base64)

    echo "Generating templates..."
    cp -R templates/infra kubectl_files
    cp -R templates/api/* kubectl_files
    sed -i "s;@@NAMESPACE@@;$NAMESPACE;" kubectl_files/*
    sed -i "s;@@PV@@;$PV;" kubectl_files/*
    sed -i "s;@@MARIADB_ROOT_PASSWORD@@;$MARIA_ROOT_PW_64;" kubectl_files/*
    sed -i "s;@@MARIADB_PASSWORD@@;$MARIA_PW_64;" kubectl_files/*
    sed -i "s;@@BASE_URL@@;$BASE_URL;" kubectl_files/*

    echo "Creating infra..."
    echo "* namespace"
    kubectl apply -f kubectl_files/00_namespace.yml

    echo "* pvc"
    if [ $PV -eq 0 ] ; then
        kubectl apply -f kubectl_files/10_pvc_generic.yml.yml
    else
        kubectl apply -f kubectl_files/10_pvc_named.yml.yml
    fi

    echo "* mysql config"
    kubectl apply -f kubectl_files/20_mysql_config.yml

    echo "* mysql deployment"
    kubectl apply -f kubectl_files/30_mysql.yml

    echo "* mysql service"
    kubectl apply -f kubectl_files/35_mysql-service.yml

    echo "* phpmyadmin deployment"
    kubectl apply -f kubectl_files/40_phpmyadmin.yml

    echo "* phpmyadmin service"
    kubectl apply -f kubectl_files/45_phpmyadmin-service.yml

    echo "* phpmyadmin ingress"
    kubectl apply -f kubectl_files/50_phpmyadmin-ingress.yml

    echo "waiting for mysql pod to be running..."
    POD_STATE="$( kubectl get pods -n $NAMESPACE | grep -ie "^mysql-" | awk '{print $3}')"
    while [ $POD_STATE -ne "Running" ] ; do
        echo "** $POD_STATE"
        sleep 2
        POD_STATE="$( kubectl get pods -n $NAMESPACE | grep -ie "^mysql-" | awk '{print $3}')"
    done

    echo "deploying mysql config..."
    MYSQL_POD_NAME=$(kubectl get pods -n $NAMESPACE | grep -ie "^mysql-" | awk '{print $1}')
    kubectl cp -n $NAMESPACE mysql/base_setup.sql $MYSQL_POD_NAME:/tmp/base_setup.sql
    kubectl exec -n $NAMESPACE -it $MYSQL_POD_NAME -- /bin/bash -c "echo /tmp/base_setup.sql | mysql -uroot -p$MARIA_ROOT_PW"


    echo ""
    echo ""
    echo "Done"
    echo "MariaDB root password:          $MARIA_ROOT_PW"
    echo "MariaDB grafanapusher password: $MARIA_PW"

    exit 0
fi


echo_help