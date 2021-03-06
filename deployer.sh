#!/bin/bash
SCRIPT_ROOT=$(cd $(dirname "$0") ; pwd)

CREATE_INFRA=0
CREATE_KEYBASED=0
CREATE_TIMEBASED=0
TABLE_NAME=""
NAMESPACE="grafana-pusher"
MARIADB_USER="grafanapusher"
MARIADB_DATABASE="grafanapusher"
PV=""
BASE_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url=*)
      BASE_URL="${1#*=}"
      ;;
    --table=*)
      TABLE_NAME="${1#*=}"
      ;;
    --namespace=*)
      NAMESPACE="${1#*=}"
      ;;
    --pv=*)
      PV="${1#*=}"
      ;;
    --create-infra)
      CREATE_INFRA=1
      ;;
    --create-keybased)
      CREATE_KEYBASED=1
      ;;
    --create-timebased)
      CREATE_TIMEBASED=1
      ;;
    -h|--help)
        CREATE_INFRA=0
        CREATE_KEYBASED=0
        CREATE_TIMEBASED=0
      ;;
    *)
        echo "INVALID ARGUMENT: $1"
        exit 1
  esac
  shift
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
    echo "  --base-url=<BASEURL>      Specify the base-url for all ingress (required)"
    echo "  --namespace=<NAMESPACE>   Specify namespace to use"
    echo "  --pv=<PV-NAME>            Specify a volume for the pvc, if not set"
    echo "                            no pv will be specified, but a generic pvc"
    echo "                            will be created"
    echo "  For api endpoints:"
    echo "  --table=<TABLENAME>       Specify table-name (required)"
    echo ""
    exit 0
}

if [ $CREATE_INFRA -eq 1 ] ; then

    # exit if not all required arguments are passed
    if [[ $BASE_URL == "" ]] ; then
        echo "ERROR: base-url is required!!"
        echo_help
        exit 1
    fi




    #############
    #   KEYS
    #############

    echo "Generating keys..."
    MARIA_PW=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-20} | head -n 1 | md5sum | awk '{print $1}')
    MARIA_PW_64=$(echo -n $MARIA_PW | base64)
    MARIA_ROOT_PW=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-20} | head -n 1 | md5sum | awk '{print $1}')
    MARIA_ROOT_PW_64=$(echo -n $MARIA_ROOT_PW | base64)

     
     

    #############
    # TEMPLATES
    #############

    echo "Generating templates..."
    cp -R $SCRIPT_ROOT/templates/infra $SCRIPT_ROOT/kubectl_files
    cp -R $SCRIPT_ROOT/templates/api/* $SCRIPT_ROOT/kubectl_files
    sed -i "s;@@NAMESPACE@@;$NAMESPACE;" $SCRIPT_ROOT/kubectl_files/*
    sed -i "s;@@PV@@;$PV;" $SCRIPT_ROOT/kubectl_files/*
    sed -i "s;@@MARIADB_ROOT_PASSWORD@@;$MARIA_ROOT_PW_64;" $SCRIPT_ROOT/kubectl_files/*
    sed -i "s;@@MARIADB_PASSWORD@@;$MARIA_PW_64;" $SCRIPT_ROOT/kubectl_files/*
    sed -i "s;@@MARIADB_USER@@;$MARIADB_USER;" $SCRIPT_ROOT/kubectl_files/*
    sed -i "s;@@MARIADB_DATABASE@@;$MARIADB_DATABASE;" $SCRIPT_ROOT/kubectl_files/*
    sed -i "s;@@BASE_URL@@;$BASE_URL;" $SCRIPT_ROOT/kubectl_files/*

    echo "Saving vars..."
    mkdir -p $SCRIPT_ROOT/config
    echo "$NAMESPACE" > $SCRIPT_ROOT/config/NAMESPACE
    echo "$PV" > $SCRIPT_ROOT/config/PV
    echo "$MARIA_ROOT_PW" > $SCRIPT_ROOT/config/MARIADB_ROOT_PASSWORD
    echo "$MARIA_PW" > $SCRIPT_ROOT/config/MARIADB_PASSWORD
    echo "$BASE_URL" > $SCRIPT_ROOT/config/BASE_URL
    echo "$MARIADB_USER" > $SCRIPT_ROOT/config/MARIADB_USER
    echo "$MARIADB_DATABASE" > $SCRIPT_ROOT/config/MARIADB_DATABASE




    #############
    # CREATING INFAR
    #############


    echo "Creating infra..."
    echo "* namespace"
    kubectl apply -f $SCRIPT_ROOT/kubectl_files/00_namespace.yml > /dev/null

    echo "* pvc"
    if [[ $PV == "" ]] ; then
        kubectl apply -f $SCRIPT_ROOT/kubectl_files/10_pvc_generic.yml > /dev/null
    else
        kubectl apply -f $SCRIPT_ROOT/kubectl_files/10_pvc_named.yml > /dev/null
    fi

    echo "* mysql config"
    kubectl apply -f $SCRIPT_ROOT/kubectl_files/20_mysql_config.yml > /dev/null

    echo "* mysql deployment"
    kubectl apply -f $SCRIPT_ROOT/kubectl_files/30_mysql.yml > /dev/null

    echo "* mysql service"
    kubectl apply -f $SCRIPT_ROOT/kubectl_files/35_mysql-service.yml > /dev/null

    echo "* phpmyadmin deployment"
    kubectl apply -f $SCRIPT_ROOT/kubectl_files/40_phpmyadmin.yml > /dev/null

    echo "* phpmyadmin service"
    kubectl apply -f $SCRIPT_ROOT/kubectl_files/45_phpmyadmin-service.yml > /dev/null

    echo "* phpmyadmin ingress"
    kubectl apply -f $SCRIPT_ROOT/kubectl_files/50_phpmyadmin-ingress.yml > /dev/null




    #############
    # MYSQL SETUP
    #############


    echo "waiting for mysql pod to be running..."
    POD_STATE="$( kubectl get pods -n $NAMESPACE | grep -ie "^mysql-" | awk '{print $3}')"
    while [[ $POD_STATE != "Running" ]] ; do
        echo "** $POD_STATE"
        sleep 2
        POD_STATE="$( kubectl get pods -n $NAMESPACE | grep -ie "^mysql-" | awk '{print $3}')"
    done
    echo "** waiting 15 seconds for mysql to be up"
    sleep 15

    echo "deploying mysql config..."
    MYSQL_POD_NAME=$(kubectl get pods -n $NAMESPACE | grep -ie "^mysql-" | awk '{print $1}')

    echo "* tables.sql"
    kubectl cp -n $NAMESPACE $SCRIPT_ROOT/mysql/tables.sql $MYSQL_POD_NAME:/tmp/tables.sql
    kubectl exec -n $NAMESPACE -it $MYSQL_POD_NAME -- /bin/bash -c "cat /tmp/tables.sql | mysql -uroot -p$MARIA_ROOT_PW $MARIADB_DATABASE"

    echo "* create_keybased.sql"
    kubectl cp -n $NAMESPACE $SCRIPT_ROOT/mysql/create_keybased.sql $MYSQL_POD_NAME:/tmp/create_keybased.sql
    kubectl exec -n $NAMESPACE -it $MYSQL_POD_NAME -- /bin/bash -c "cat /tmp/create_keybased.sql | mysql -uroot -p$MARIA_ROOT_PW $MARIADB_DATABASE"

    echo "* create_timebased.sql"
    kubectl cp -n $NAMESPACE $SCRIPT_ROOT/mysql/create_timebased.sql $MYSQL_POD_NAME:/tmp/create_timebased.sql
    kubectl exec -n $NAMESPACE -it $MYSQL_POD_NAME -- /bin/bash -c "cat /tmp/create_timebased.sql | mysql -uroot -p$MARIA_ROOT_PW $MARIADB_DATABASE"

    echo "* delete_table.sql"
    kubectl cp -n $NAMESPACE $SCRIPT_ROOT/mysql/delete_table.sql $MYSQL_POD_NAME:/tmp/delete_table.sql
    kubectl exec -n $NAMESPACE -it $MYSQL_POD_NAME -- /bin/bash -c "cat /tmp/delete_table.sql | mysql -uroot -p$MARIA_ROOT_PW $MARIADB_DATABASE"


    #############
    #   ENDING
    #############



    echo ""
    echo ""
    echo "Done"
    echo "PHPMyAdmin URL:                 management.$BASE_URL"
    echo "MariaDB root password:          $MARIA_ROOT_PW"
    echo "MariaDB grafanapusher password: $MARIA_PW"

    exit 0
fi


if [ $CREATE_KEYBASED -eq 1 ] || [ $CREATE_TIMEBASED -eq 1 ] ; then

    # exit if not all required arguments are passed
    if [[ $TABLE_NAME == "" ]] ; then
        echo "ERROR: table is required!!"
        echo_help
        exit 1
    fi

    echo "checking on folder"
    test -d $SCRIPT_ROOT/endpoint_files || mkdir -p $SCRIPT_ROOT/endpoint_files

    echo "generating template"
    sed "s;@@TABLE_NAME@@;$TABLE_NAME;" $SCRIPT_ROOT/kubectl_files/99_create_endpoint.yml > $SCRIPT_ROOT/endpoint_files/$TABLE_NAME.yml

    echo "creating pod"
    kubectl apply -f $SCRIPT_ROOT/endpoint_files/$TABLE_NAME.yml > /dev/null

    echo "running mysql procedure"
    MYSQL_POD_NAME=$(kubectl get pods -n $(cat $SCRIPT_ROOT/config/NAMESPACE) | grep -ie "^mysql-" | awk '{print $1}')

    if [ $CREATE_KEYBASED -eq 1 ] ; then
        authKey="$(kubectl exec -n $(cat $SCRIPT_ROOT/config/NAMESPACE) -it $MYSQL_POD_NAME -- /bin/bash -c "echo \"CALL create_keybased('$TABLE_NAME');\" | mysql -u$(cat $SCRIPT_ROOT/config/MARIADB_USER) -p$(cat $SCRIPT_ROOT/config/MARIADB_PASSWORD) $(cat $SCRIPT_ROOT/config/MARIADB_DATABASE)"  | tail -n1 | awk '{print $2}')"
    else
        authKey="$(kubectl exec -n $(cat $SCRIPT_ROOT/config/NAMESPACE) -it $MYSQL_POD_NAME -- /bin/bash -c "echo \"CALL create_timebased('$TABLE_NAME');\" | mysql -u$(cat $SCRIPT_ROOT/config/MARIADB_USER) -p$(cat $SCRIPT_ROOT/config/MARIADB_PASSWORD) $(cat $SCRIPT_ROOT/config/MARIADB_DATABASE)" | tail -n1 | awk '{print $2}')"
    fi

    echo ""
    echo ""
    echo "Done"
    echo "Table Name:        $TABLE_NAME"
    echo "API Endpoint:      api-$TABLE_NAME.$(cat $SCRIPT_ROOT/config/BASE_URL)"
    echo "Authorization Key: $authKey"

    exit 0
fi


echo_help