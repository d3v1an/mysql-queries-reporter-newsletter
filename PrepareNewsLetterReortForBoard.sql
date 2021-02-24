CREATE DEFINER=`root`@`localhost` PROCEDURE `PrepareNewsLetterReportForBoard`(
	IN board VARCHAR(35),
	IN block VARCHAR(35),
	IN `option` VARCHAR(35),
    IN output INT
)
BEGIN

	DECLARE finished INTEGER DEFAULT 0;
	
	DECLARE text VARCHAR(150);
	DECLARE orden INTEGER DEFAULT 0;
	DECLARE main TEXT;
	DECLARE estados TEXT;
	DECLARE revistas TEXT;
	DECLARE web TEXT;
	
	DECLARE firstPartQuery TEXT;
	
	DECLARE board_cursor CURSOR
	FOR(
		SELECT
			menu_items.text,
			menu_items.`order` as orden,
			menu_items.`query` AS `main`,
			menu_items.query_estados AS estados,
			menu_items.query_revistas AS revistas,
			menu_items.query_web AS web
		FROM
				boards
				INNER JOIN menus ON boards.id=menus.board_id
				INNER JOIN menu_items ON menus.id=menu_items.menu_id
		WHERE
				boards.alias=board COLLATE utf8_unicode_ci AND
				position = 'left' AND
				menu_items.type = 'sql' AND
				menu_items.text NOT LIKE '%Varios%' AND
				menu_items.text NOT LIKE '%Encuestas%' AND
				menu_items.text NOT LIKE '%Cobertura%' AND
				menu_items.text NOT LIKE '%e-paper%' AND
				menu_items.text NOT LIKE '%Grafica%'
		ORDER BY `order`
	);
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
	
	OPEN board_cursor;
	
	SET firstPartQuery = 'INSERT INTO `noticiasReportesData`(titulo,encabezado,texto,stringName,periodico,pagina,estado,seccion,categoria,autor,fecha,hora,pdf,board,`type`,`order`,`character`,`option`) SELECT TRIM(n.Titulo) as titulo, TRIM(n.Encabezado) as encabezado, TRIM(n.Texto) as texto, p.String_Name AS stringName, p.Nombre AS periodico, n.PaginaPeriodico AS pagina, e.Nombre AS estado, TRIM(s.seccion) as seccion, TRIM(c.Categoria) as categoria, n.Autor as autor, n.Fecha as fecha, n.Hora as hora, n.NumeroPagina AS pdf ';
	
	-- Clean data
	SET @dataToClear = "DELETE FROM `noticiasReportesData` WHERE board = ? AND type = ? AND fecha <= CURDATE()";
	
	PREPARE CLEAR_QUERY FROM @dataToClear;
	SET @board = board;
	SET @type = block;
	EXECUTE CLEAR_QUERY USING @board, @type;
	DEALLOCATE PREPARE CLEAR_QUERY;
	
	thisLoop:LOOP
	
		FETCH board_cursor INTO text, orden, main, estados, revistas, web;
		
		IF finished <> 0 THEN
			LEAVE thisLoop;
		END IF;
		
		CASE block
			WHEN 'main' THEN
				SET @query = main;
			WHEN 'estados' THEN
				SET @query = estados;
			WHEN 'revistas' THEN
				SET @query = revistas;
			WHEN 'web' THEN
				SET @query = main;
			ELSE
				SET @query = main;
		END CASE;

		IF LOCATE('#',@query) THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El query contiene un caracter invalido.';
		ELSE
		
			SET @cleanMain = REPLACE(@query,'\n',' ');
			SET @extractedMain = SUBSTRING(@cleanMain, POSITION("FROM" IN @cleanMain));
			SET @queryompose = CONCAT(firstPartQuery, ", '", board, "' as board, '", block, "' as `type`, ", orden, " as `order`, '", text, "' as `character`, '",`option`, "' as `option` ");
			SET @exportMain = CONCAT(@queryompose, @extractedMain);
			
			PREPARE QUERY FROM @exportMain;
			EXECUTE QUERY;
			DEALLOCATE PREPARE QUERY;
			
		END IF;
	END LOOP;
	CLOSE board_cursor;
	
SELECT 'Done' AS Status;
END