DROP DATABASE IF EXISTS `gb_talks`;
CREATE DATABASE `gb_talks`;
USE `gb_talks`;

CREATE TABLE `talks`(
`id` INT(3) NOT NULL,
`year`YEAR(4) NOT NULL,
`speaker` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
`title` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
`available` INT(1) DEFAULT 0 NOT NULL,
`priority` INT(2) DEFAULT 10 NOT NULL,
`uploaded` TINYINT(1) DEFAULT 0 NOT NULL,
`start_time` DATETIME DEFAULT 0 NOT NULL,
PRIMARY KEY (`id`, `year`)
) ENGINE = InnoDB;

CREATE TABLE `orders` (
`id` INT(3) NOT NULL,
`year` YEAR(4) NOT NULL,
`complete` TINYINT(1) NOT NULL DEFAULT 0,
`additional_talks` TEXT DEFAULT NULL,
PRIMARY KEY (`id`, `year`)
) ENGINE = InnoDB;

CREATE TABLE `order_items` (
 `order_id` INT(3) NOT NULL,
 `order_year` YEAR(4) NOT NULL,
 `talk_id` INT(3) NOT NULL,
 `talk_year` YEAR(4) NOT NULL,
PRIMARY KEY `pk_order_items` ( `order_id` , `talk_id` ) ,
CONSTRAINT `fk_order_items_talk` 
	FOREIGN KEY `fk_order_items_talk` (`talk_id`, `talk_year`) 
	REFERENCES `talks`(`id`, `year`) 
	ON DELETE RESTRICT 
	ON UPDATE CASCADE,
CONSTRAINT `fk_order_items_order` 
	FOREIGN KEY `fk_order_items_order` (`order_id`, `order_year`) 
	REFERENCES `orders`(`id`, `year`) 
	ON DELETE RESTRICT 
	ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE `upload_queue` (
`sequence` INT(3) PRIMARY KEY NOT NULL AUTO_INCREMENT,
`priority` INT(1) NOT NULL,
`talk_id` INT(3) UNIQUE NOT NULL,
`talk_year` YEAR(4) NOT NULL,
CONSTRAINT `fk_upload_queue_talk`
        FOREIGN KEY `fk_upload_queue_talk` (`talk_id`, `talk_year`)
        REFERENCES `talks`(`id`,`year`)
        ON DELETE CASCADE
        ON UPDATE RESTRICT)
ENGINE = InnoDB;

CREATE TABLE `transcode_queue` (
`sequence` INT(3) PRIMARY KEY NOT NULL AUTO_INCREMENT,
`priority` INT(1) NOT NULL,
`talk_id` INT(3) UNIQUE NOT NULL,
`talk_year` YEAR(4) NOT NULL,
CONSTRAINT `fk_transcode_queue_talk`
        FOREIGN KEY `fk_transcode_queue_talk` (`talk_id`,`talk_year`)
        REFERENCES `talks`(`id`,`year`)
        ON DELETE CASCADE
        ON UPDATE RESTRICT)
ENGINE = InnoDB;

