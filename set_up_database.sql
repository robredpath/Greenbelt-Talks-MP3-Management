CREATE TABLE `talks` (
`id` INT(3) PRIMARY KEY NOT NULL,
`year` INT(2) NOT NULL,
`speaker` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
`title` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
`available` INT(1) DEFAULT 0 NOT NULL )
ENGINE = InnoDB;

CREATE TABLE `orders` (
`id` INT(3) PRIMARY KEY NOT NULL );
ENGINE = InnoDB;

CREATE TABLE `order_items` (
`order_id` INT(3) NOT NULL PRIMARY KEY,
`talk_id` INT(3) NOT NULL,
CONSTRAINT `unique_order_items`
	UNIQUE KEY `unique_order_items` (`order_id`,`talk_id`),
CONSTRAINT `fk_order_items_orders` 
	FOREIGN KEY `fk_order_items_orders`(`order_id`)
	REFERENCES `orders`(`id`) 
	ON DELETE NO ACTION 
	ON UPDATE NO ACTION,
CONSTRAINT `fk_order_items_talks` 
        FOREIGN KEY `fk_order_items_talks`(`talk_id`)
        REFERENCES `talks`(`id`) 
        ON DELETE NO ACTION 
        ON UPDATE NO ACTION)
ENGINE = InnoDB;

CREATE TABLE `upload_queue` (
`sequence` INT(3) PRIMARY KEY NOT NULL,
`priority` INT(1) NOT NULL,
`talk_id` INT(3) UNIQUE NOT NULL,
CONSTRAINT `fk_upload_queue_talks` 
        FOREIGN KEY `fk_upload_queue_talks`(`talk_id`)
        REFERENCES `talks`(`id`) 
        ON DELETE NO ACTION 
        ON UPDATE NO ACTION)
ENGINE = InnoDB;

CREATE TABLE `transcode_queue` (
`sequence` INT(3) PRIMARY KEY NOT NULL,
`priority` INT(1) NOT NULL,
`talk_id` INT(3) UNIQUE NOT NULL,
CONSTRAINT `fk_transcode_queue_talks` 
        FOREIGN KEY `fk_transcode_queue_talks`(`talk_id`)
        REFERENCES `talks`(`id`) 
        ON DELETE NO ACTION
        ON UPDATE NO ACTION)
ENGINE = InnoDB;


