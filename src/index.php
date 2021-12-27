<?php

$pdo = new PDO("mysql:host=".$_ENV["MARIADB_HOST"].";dbname=".$_ENV["MARIADB_DATABASE"], $_ENV["MARIADB_USER"], $_ENV["MARIADB_PASSWORD"]);

$query = $pdo->prepare("SELECT authkey FROM tableconfig WHERE tablename = ?");
$query->execute(array($_ENV["GRAFPUSH_TABLENAME"]));   
$row = $query->fetch();
print_r($row);
