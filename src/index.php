<?php

try{


    $pdo = new PDO("mysql:host=".$_ENV["MARIADB_HOST"].";dbname=".$_ENV["MARIADB_DATABASE"], $_ENV["MARIADB_USER"], $_ENV["MARIADB_PASSWORD"]);
    
    $query = $pdo->prepare("SELECT authkey,mode FROM tableconfig WHERE tablename = ?");
    $query->execute(array($_ENV["GRAFPUSH_TABLENAME"]));   
    
    $authKey = $query->fetch()["authkey"];
    $mode = $query->fetch()["mode"];
    
    if($_SERVER["HTTP_AUTH"] == $authKey){

        if(isset($_POST['key']) && isset($_POST['value'])){
            if($mode == 1){
                $sql = "INSERT INTO data_".$_ENV['GRAFPUSH_TABLENAME']."(`key`,`value`) VALUES('".$_POST['key']."','".$_POST['value']."') ON DUPLICATE KEY UPDATE `value` = '".$_POST['value']."'";
            } else {
                $sql = "INSERT INTO data_".$_ENV['GRAFPUSH_TABLENAME']."(`key`,`value`) VALUES('".$_POST['key']."','".$_POST['value']."')";
            }

            $query = $pdo->prepare($sql);
            $query->execute();
        } else {
            echo "504 not enough data";
        }

    } else {
        echo "403 permission denied";
        exit;
    }

}catch(\Throwable $e){
    echo "some error occured";
}