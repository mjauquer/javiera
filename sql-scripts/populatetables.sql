INSERT INTO file_type_name (id, extension, name) VALUES
	('', '','Regular'),
		('', '', 'Audio'),
			('', '', 'Uncompressed'),
				('', 'wav', 'Waveform Audio Format'),
				('', 'aiff', 'Audio Interchange File Format'),
			('', '', 'Compressed'),
				('', '', 'Lossless'),
				('', '', 'Lossy'),
		('', '', 'Archive'),
			('', '', 'Archiving only'),
			('', '', 'Archiving and compression'),
			( '','', 'Compression only'),
			( '','', 'Disk image'),
		('', '', 'Parity'),
		('', '', 'Multimedia Container')
;

INSERT INTO file_type (id, parent, left_extent, right_extent, name) VALUES
	('', NULL, '', '', (SELECT id FROM file_type_name WHERE name='Regular')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Audio')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Uncompressed')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Waveform Audio Format')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Audio Interchange File Format')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Compressed')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Lossless')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Lossy')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Archive')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Archiving only')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Archiving and compression')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Compression only')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Disk image')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Parity')),
	('', '', '', '', (SELECT id FROM file_type_name WHERE name='Multimedia Container'))
;

create TABLE aux_table 
(
	id    MEDIUMINT UNSIGNED NOT NULL,
	name  VARCHAR(256) NOT NULL
);

INSERT INTO aux_table (id, name) 
	SELECT file_type.id, file_type_name.name FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id;

UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Regular') 
	WHERE id=(SELECT id FROM aux_table WHERE name='Audio');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Audio') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Uncompressed');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Uncompressed') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Waveform Audio Format');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Uncompressed') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Audio Interchange File Format');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Audio') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Compressed');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Compressed') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Lossless');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Compressed') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Lossy');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Regular') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Archive');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Archive') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Archiving only');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Archive') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Archiving and compression');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Archive') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Compression only');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Archive') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Disk image');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Regular') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Parity');
UPDATE file_type SET parent=(SELECT id FROM aux_table WHERE name='Regular') 
	WHERE name=(SELECT id FROM aux_table WHERE name='Multimedia Container');

DROP TABLE aux_table;

INSERT INTO mime (id, type) VALUES
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

INSERT INTO l_file_type_mime (file_type, mime) 
	VALUES (
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Waveform Audio Format'), 
		(SELECT id FROM mime WHERE type='audio/wav')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Waveform Audio Format'), 
		(SELECT id FROM mime WHERE type='audio/x-wav')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Waveform Audio Format'), 
		(SELECT id FROM mime WHERE type='audio/wave')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Waveform Audio Format'), 
		(SELECT id FROM mime WHERE type='audio/x-pn-wav')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Waveform Audio Format'), 
		(SELECT id FROM mime WHERE type='audio/vnd-wave')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/aiff')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/x-aiff')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='sound/aiff')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/rmf')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/x-rmf')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/x-pn-aiff')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/x-gsm')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/mid')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/x-midi')
	),
	(
		(SELECT file_type.id 
			FROM file_type LEFT JOIN file_type_name ON file_type.name=file_type_name.id 
			WHERE file_type_name.name='Audio Interchange File Format'), 
		(SELECT id FROM mime WHERE type='audio/vnd-qcelp')
	)
;

delimiter //

CREATE PROCEDURE GENERATE_NESTED_SETS_MODEL_ON_file_type_TABLE()
BEGIN

	-- Create the stack table.
	CREATE TABLE stack 
	(
		ID          INT AUTO_INCREMENT,
		fileTypeID  INT NOT NULL,
		leftExtent  INT,
		rightExtent INT,
		PRIMARY KEY (ID)
	);
	
	-- Use @counter to set the left and right extent.
	SET @counter = 1;

	-- Test if parentid has got children. If it does, push it onto
	-- the stack and move on to the next child.
	loop1: LOOP

		-- Get the first row which is a child of parentid and
		-- has not already been pushed onto the stack.
		INSERT INTO stack (fileTypeID, leftExtent)
			SELECT id, @counter
				FROM file_type 
				WHERE COALESCE(parent, 0) = COALESCE(@parentid, 0)
				AND id NOT IN (SELECT fileTypeID FROM stack) LIMIT 1;
		
		-- @id:    the ID value of the last inserted row.
		-- @oldid: the ID value of the row at the top of the
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
			SELECT @id := ID
				FROM stack
				WHERE rightExtent IS NULL ORDER BY ID DESC LIMIT 1;

			-- Test if there are more rows to pop. Exit the
			-- procedure if it is so.
			IF @id IS NULL
			THEN
				LEAVE loop1;
			END IF;

			UPDATE stack
			SET rightExtent = @counter
			WHERE ID = @id;

			SET @counter = @counter + 1;

			SELECT @parentid := parent
			FROM file_type
			WHERE id = (SELECT fileTypeID FROM stack WHERE ID = @id);
		ELSE
			-- Move on to the next level. We take the parent
			-- id of the next item from the id value of the
			-- one that has been just inserted.
			SELECT @parentid := fileTypeID
				FROM stack 
				WHERE ID = @id;
		END IF;
	END LOOP loop1;

UPDATE file_type ft INNER JOIN stack st ON st.fileTypeID = ft.id
SET ft.left_extent = st.leftExtent, ft.right_extent = st.rightExtent;

SET @id = NULL;
SET @oldid = NULL;
SET @parentid = NULL;
SET @counter = NULL;

END;

//

delimiter ;

CALL GENERATE_NESTED_SETS_MODEL_ON_file_type_TABLE();

DROP TABLE stack;
DROP PROCEDURE GENERATE_NESTED_SETS_MODEL_ON_file_type_TABLE;
