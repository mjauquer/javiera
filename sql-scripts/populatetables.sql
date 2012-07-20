INSERT INTO host (id, name)
	VALUES
		('', 'cym')
;

INSERT INTO description (id, text)
	VALUES 
		('', 'regular'),
			('', 'audio'),
				('', 'uncompressed'),
					('', 'waveform audio format'),
					('', 'wav'),
					('', 'audio interchange file format'),
					('', 'aif'),
					('', 'aiff'),
				('', 'compressed'),
					('', 'lossless'),
						('', 'free lossless audio codec'),
						('', 'flac'),
					('', 'lossy'),
			('', 'archive'),
				('', 'archiving only'),
				('', 'archiving and compression'),
				('', 'compression only'),
				('', 'disk image'),
			('', 'parity'),
			('', 'multimedia container')
;

INSERT INTO tree (id, name) VALUES ('', 'file type hierarchy');

INSERT INTO tree_node (id, parent_id) VALUES ('', NULL);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id) VALUES
	(@tree_node_id, (SELECT id FROM tree WHERE name='file type hierarchy'));
INSERT INTO l_tree_node_to_description (tree_node_id, description_id) VALUES
	(@tree_node_id, (SELECT id FROM description WHERE text='regular'));
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='regular')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id, 
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='audio')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='audio')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='uncompressed')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='uncompressed')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='waveform audio format')
	),(
		@tree_node_id,
		(SELECT id FROM description WHERE text='wav')
	)
;
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='uncompressed')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='audio interchange file format')
	),(
		@tree_node_id,
		(SELECT id FROM description WHERE text='aiff')
	),(
		@tree_node_id,
		(SELECT id FROM description WHERE text='aif')
	)
;
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='audio')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='compressed')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='compressed')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='lossless')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='lossless')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='free lossless audio format')
	),(
		@tree_node_id,
		(SELECT id FROM description WHERE text='flac')
	)
;
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='compressed')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id, (SELECT id FROM description WHERE text='lossy')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='regular')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='archive')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='archive')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='archiving only')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='archive')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='archiving and compression')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='archive')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='compression only')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='archive')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='disk image')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='regular')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='parity')
	);
SET @tree_node_id = NULL;

INSERT INTO tree_node (id, parent_id)
	VALUES (
		'',
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS node LEFT JOIN description
			ON node.description_id = description.id 
			WHERE text='regular')
	);
SET @tree_node_id = LAST_INSERT_ID();
INSERT INTO l_tree_node_to_tree (tree_node_id, tree_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM tree WHERE name='file type hierarchy')
	);
INSERT INTO l_tree_node_to_description (tree_node_id, description_id)
	VALUES (
		@tree_node_id,
		(SELECT id FROM description WHERE text='multimedia container')
	);
SET @tree_node_id = NULL;

INSERT INTO mime_type (id, type) VALUES
	('', 'audio/wav'),
	('', 'audio/x-wav'),
	('', 'audio/wave'),
	('', 'audio/x-pn-wav'),
	('', 'audio/vnd-wave'),
	('', 'audio/aiff'),
	('', 'audio/x-aiff'),
	('', 'sound/aiff'),
	('', 'audio/rmf'),
	('', 'audio/x-rmf'),
	('', 'audio/x-pn-aiff'),
	('', 'audio/x-gsm'),
	('', 'audio/mid'),
	('', 'audio/x-midi'),
	('', 'audio/vnd-qcelp')
;

INSERT INTO l_mime_type_to_tree_node (tree_node_id, mime_type_id) 
	VALUES (
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='waveform audio format'), 
		(SELECT id FROM mime_type WHERE type='audio/wav')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='waveform audio format'), 
		(SELECT id FROM mime_type WHERE type='audio/x-wav')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='waveform audio format'), 
		(SELECT id FROM mime_type WHERE type='audio/wave')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='waveform audio format'), 
		(SELECT id FROM mime_type WHERE type='audio/x-pn-wav')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='waveform audio format'), 
		(SELECT id FROM mime_type WHERE type='audio/vnd-wave')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/aiff')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/x-aiff')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='sound/aiff')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/rmf')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/x-rmf')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/x-pn-aiff')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/x-gsm')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/mid')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/x-midi')
	),
	(
		(SELECT tree_node_id 
			FROM l_tree_node_to_description AS link LEFT JOIN description ON link.description_id=description.id 
			WHERE description.text='audio interchange file format'), 
		(SELECT id FROM mime_type WHERE type='audio/vnd-qcelp')
	)
;

delimiter //

CREATE PROCEDURE generate_nested_sets_model(IN title VARCHAR(256))
BEGIN

	-- Create the stack table.
	CREATE TABLE stack 
	(
		id           INT AUTO_INCREMENT,
		node_id      INT NOT NULL,
		left_extent  INT,
		right_extent INT,
		PRIMARY KEY (id)
	);
	
	-- Use @counter to set the left and right extent.
	SET @counter = 1;

	-- Test if parentid has got children. If it does, push it onto
	-- the stack and move on to the next child.
	loop1: LOOP

		-- Get the first row which is a child of parentid and
		-- has not already been pushed onto the stack.
		INSERT INTO stack (node_id, left_extent)
			SELECT tree_node.id, @counter
				FROM l_tree_node_to_tree AS link
					INNER JOIN tree ON link.tree_id = tree.id
					RIGHT JOIN tree_node ON link.tree_node_id = tree_node.id
				WHERE name = title
				AND COALESCE(parent_id, 0) = COALESCE(@parentid, 0)
				AND tree_node.id NOT IN (SELECT node_id FROM stack) LIMIT 1;
		
		-- @id:    the id value of the last inserted row.
		-- @oldid: the id value of the row at the top of the
		--         stack.
		SET @id = LAST_INSERT_ID();
		IF COALESCE(@id, 0) = COALESCE(@oldid, 0) 
		THEN
			SET @id = NULL;
		ELSE
			SET @oldid = @id;
			SET @counter = @counter + 1;
		END IF;

		-- Test if a new row have been inserted in the stack at
		-- the beginning of this iteration.
		IF @id IS NULL
		THEN
			-- No it haven't. Pop the row at the top of the
			-- stack.
			SELECT @id := id
				FROM stack
				WHERE right_extent IS NULL ORDER BY id DESC LIMIT 1;

			-- Test if there are more rows to pop. Exit the
			-- procedure if it is so.
			IF @id IS NULL
			THEN
				LEAVE loop1;
			END IF;

			UPDATE stack
			SET right_extent = @counter
			WHERE id = @id;

			SET @counter = @counter + 1;

			SELECT @parentid := parent_id
			FROM tree_node
			WHERE id = (SELECT node_id FROM stack WHERE id = @id);
		ELSE
			-- Move on to the next level. We take the parent
			-- id of the next item from the id value of the
			-- one that has been just inserted.
			SELECT @parentid := node_id
				FROM stack 
				WHERE id = @id;
		END IF;
	END LOOP loop1;

UPDATE tree_node ft INNER JOIN stack st ON st.node_id = ft.id
SET ft.left_extent = st.left_extent, ft.right_extent = st.right_extent;

SET @id = NULL;
SET @oldid = NULL;
SET @parentid = NULL;
SET @counter = NULL;

END;

//

delimiter ;

CALL generate_nested_sets_model('file type hierarchy');

DROP TABLE stack;
DROP PROCEDURE generate_nested_sets_model;
