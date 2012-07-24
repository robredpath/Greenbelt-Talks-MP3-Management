DELETE FROM `gb_talks`.`order_items`;
DELETE FROM `gb_talks`.`orders`;
DELETE FROM `gb_talks`.`talks`;

INSERT INTO `gb_talks`.`talks` 
(`id`,`year`,`speaker`,`title`,`available`)
VALUES
('1', '2012', 'Mr E Xample', 'An Awesome Talk', '1'),
('2', '2012', 'Mr E Xample', 'Another Awesome Talk', '1'),
('3', '2012', 'Mr E Xample', 'A Talk That You Can''t Have Yet', '0'),
('95', '2012', 'Ms S Peaker', 'A Talk About Something', '0'),
('108', '2011', 'Mr E Xample', 'An Awesome Talk from 2011', '1'),
('25', '2011', 'Mrs Ann Other', 'A Boring Talk from 2011', '1');

INSERT INTO `gb_talks`.`orders` 
(`id`,`year`)
VALUES 
('1','2012'),
('2','2012'),
('100', '2012'),
('78', '2012'),
('987', '2012'),
('10', '2011'),
('83', '2011'),
('282', '2011');

INSERT INTO `gb_talks`.`order_items` 
(`order_id`, `order_year`, `talk_id`, `talk_year`)
VALUES
('2','2012','3','2012'),
('2','2012','95','2012'),
('987','2012', '108','2011'),
('100','2012','1','2012'),
('100','2012','2','2012'),
('100','2012','3','2012'),
('100','2012','95','2012'),
('100','2012','108','2011'),
('100','2012','25','2011');

-- Commented out due to SQL not liking blank INSERT statements

-- INSERT INTO transcode_queue VALUES (
-- 
-- )
-- 
-- INSERT INTO upload_queue VALUES (
-- 
-- )

