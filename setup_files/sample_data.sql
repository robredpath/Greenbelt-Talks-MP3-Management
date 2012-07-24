TRUNCATE TABLE `gb_talks`.`order_items`;
TRUNCATE TABLE `gb_talks`.`orders`;
TRUNCATE TABLE `gb_talks`.`talks`;

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
(`id`)
VALUES 
('1'),
('2'),
('100'),
('78'),
('987');

INSERT INTO `gb_talks`.`order_items` 
(`order_id`, `talk_id`)
VALUES
('2','3'),
('2','95'),
('987', '108'),
('100','1'),
('100','2'),
('100','3'),
('100','95'),
('100','108'),
('100','25');

-- Commented out due to SQL not liking blank INSERT statements

-- INSERT INTO transcode_queue VALUES (
-- 
-- )
-- 
-- INSERT INTO upload_queue VALUES (
-- 
-- )

