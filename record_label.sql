/* Database link: https://github.com/lerocha/chinook-database/releases/tag/v1.4.0 */

/* 1. Implement a routine that returns the number of tracks sold in a given time interval. */

DELIMITER #
CREATE FUNCTION point1 (start_date DATE, end_date DATE)
RETURNS INT
BEGIN
DECLARE total INT;
SELECT SUM(b.quantity) INTO total
FROM invoice a
JOIN invoiceline b
ON a.InvoiceId=b.InvoiceId
WHERE a.InvoiceDate BETWEEN start_date AND end_date;
RETURN total;
END #

SELECT point1 ('2010-01-01','2010-12-31') AS total;

/* 2. Implement a program that will receive an album id when called and return the number of songs on that album,
the artist to whom the album belongs, the musical genre it falls into, and the total value of that album's sales. */

DELIMITER #
CREATE PROCEDURE point2 (IN var_id INT)
BEGIN
SELECT COUNT(a.trackid) number_track, b.title album_name, MAX(c.name) artist_name, MAX(d.name), SUM(e.unitprice*e.quantity) value_sales
FROM track a
JOIN album b
ON a.albumid=b.albumid
JOIN artist c
ON b.artistid=c.artistid
JOIN genre d
ON d.genreid=a.genreid 
JOIN invoiceline e
ON e.trackid=a.trackid
WHERE b.albumid=var_id
GROUP BY b.title;
END #

CALL point2(1);

/* 3. Implement a routine that displays the artists whose songs were purchased by customers from a specific country. */

DELIMITER #
CREATE PROCEDURE point3 (IN var_country VARCHAR(50))
BEGIN
SELECT DISTINCT a.name FROM artist a
JOIN album b 
ON a.artistid=b.artistid
JOIN track c
ON b.albumid=c.albumid
JOIN invoiceline d
ON c.trackid=d.trackid
JOIN invoice e
ON d.invoiceid=e.invoiceid
WHERE e.billingcountry=var_country;
END #

CALL point3('Argentina');

/* 4. Implement a routine that returns the invoices from a given year 
whose value is greater than the average invoice value for that year. */

DELIMITER #
CREATE PROCEDURE point4 (IN var_year INT)
BEGIN
SELECT invoiceid, customerid, billingaddress FROM invoice WHERE total>
(SELECT AVG(total) FROM invoice
WHERE YEAR(invoicedate)=var_year)
AND YEAR(invoicedate)=var_year;
END #

CALL point4(2010);

/* 5. Implement a routine that displays the top 30 best-selling songs based on a specific musical genre. */

DELIMITER #
CREATE PROCEDURE point5 (IN var_genre VARCHAR(50))
BEGIN
SELECT a.name, SUM(c.unitprice*c.quantity) as value_sales
FROM track a
JOIN genre b
ON a.genreid=b.genreid
JOIN invoiceline c
on a.trackid=c.trackid
WHERE b.name=var_genre
GROUP BY a.name
ORDER BY value_sales DESC
LIMIT 30;
END #

CALL point5('Rock');

/* 6. Implement a program that returns the value of invoices for a given album. */

DELIMITER #
CREATE PROCEDURE point6(IN var_album VARCHAR(50))
BEGIN
SELECT c.title, SUM(a.unitprice*a.quantity) value_invoices FROM invoiceline a
JOIN track b
ON a.trackid=b.trackid
JOIN album c
ON b.albumid=c.albumid
WHERE c.title=var_album
GROUP BY c.title;
END #

CALL point6('For Those About To Rock We Salute You');

/* 7. Implement a routine that displays the position of a song in the sales chart,
the name of the song, the album it is on, the musical genre it is included in
and the artist it belongs to. */

DELIMITER #
CREATE PROCEDURE point7 (IN var_id INT)
BEGIN
SELECT position, TrackName, TrackId, AlbumTitle, GenreName, ArtistName FROM
(SELECT ROW_NUMBER() OVER
(ORDER BY SUM(b.unitprice*b.quantity) DESC) as position, a.name TrackName, MAX(b.trackid) TrackId, MAX(c.title) AlbumTitle, MAX(d.name) ArtistName, MAX(e.name) GenreName
FROM track a
JOIN invoiceline b
ON a.trackid=b.trackid
JOIN album c
ON a.albumid=c.albumid
JOIN artist d
ON c.artistid=d.artistid
JOIN genre e
ON a.genreid=e.genreid
GROUP BY a.name) sales_chart
WHERE TrackId=var_id;
END #

CALL point7('1339');

/* 8. Implement a program that, when an invoice is deleted, 
deletes all the elements related to that invoice 
(the details of that invoice) and inserts 
into a newly created table a history of deletions
that contains the number of the invoice that was deleted,
the date when the deletion was made, the value of that invoice
and the name of the customer to whom the invoice belonged. 
The program will allow the invoice to be deleted only if
its value is not greater than 10. Otherwise, it will generate an error message */

CREATE TABLE invoice_history
(no_invoice INT, 
deletion_date DATETIME, 
invoice_value DOUBLE, 
name_client VARCHAR(100));

DELIMITER #
CREATE TRIGGER point8 BEFORE DELETE
ON invoice
FOR EACH ROW
BEGIN
DECLARE name_client VARCHAR(100);
IF OLD.total>10 THEN
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT="Can't do, too high of a value";
ELSE
	DELETE FROM invoiceline
    WHERE invoiceid=OLD.invoiceid;
    SELECT CONCAT(firstName,' ',lastName) INTO name_client
    FROM customer
    WHERE customerID=OLD.customerID;
    INSERT INTO invoice_history VALUES
    (OLD.invoiceid, NOW(), OLD.total, name_client);
END IF;
END #

DELETE FROM invoice WHERE invoiceid=4;
SELECT * FROM customer;

/* 9. Implement a program that will return the top 10 artists with the most albums. */

DELIMITER #
CREATE PROCEDURE point9 (IN var_top INT)
BEGIN
SELECT a.name, COUNT(b.albumid) AS total_albums
FROM artist a
JOIN album b
ON a.artistid=b.artistid
GROUP BY a.name
ORDER BY 2 DESC
LIMIT var_top;
END #

CALL point9(5);

/* 10. Implement a program that will return the number of tracks that are not found on any invoice. */

DELIMITER #
CREATE PROCEDURE point10()
BEGIN
SELECT NAME, composer, unitprice FROM track a WHERE NOT EXISTS
(SELECT 1 FROM invoiceline b WHERE a.trackid=b.trackid);
END #

CALL point10();

/* 11. Implement a program that automatically adds a newly entered track to the Track table
on the last playlist that contains a song from that album. */

DELIMITER #
CREATE TRIGGER point11 AFTER INSERT
ON track
FOR EACH ROW
BEGIN
DECLARE var_playlistid INT;
DECLARE var_trackid INT;
SELECT playlistid INTO var_playlistid
FROM playlisttrack WHERE trackid IN
(SELECT trackid FROM track WHERE albumid=NEW.albumid)
ORDER BY playlistid DESC
LIMIT 1;
	BEGIN
	SELECT trackid INTO var_trackid FROM track WHERE trackid=NEW.trackid;
	INSERT INTO playlisttrack VALUES (var_playlistid, var_trackid);
    END ;
END #

SELECT playlistid, trackid FROM playlisttrack WHERE trackid IN (SELECT trackid FROM track WHERE albumid=2);
START TRANSACTION;
INSERT INTO track (trackid,name,albumid,mediatypeid,genreid,milliseconds,bytes,unitprice) VALUES (3504,"Losing More Than You've Ever Had",2,2,1,222,333,0.99);
SELECT playlistid, trackid FROM playlisttrack WHERE trackid IN (SELECT trackid FROM track WHERE albumid=2);
ROLLBACK;

/* 12. Implement a program that checks that when a new value is entered in the customers table,
the email address contains the @ symbol and the phone number has at least 10 characters.
If these conditions are met, the new customer is allowed to be added.
Otherwise, an error message will be displayed. */

DELIMITER #
CREATE TRIGGER point12 BEFORE INSERT
ON customer
FOR EACH ROW
validation: BEGIN
IF NEW.email LIKE '%@%' AND LENGTH(NEW.phone) >= 10 THEN
	LEAVE validation;
ELSE
	SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid email or fax';
END IF;
END #

INSERT INTO customer VALUES (43,'Zeljko','Raznatovic','Arkanovci',NULL,'Erdut',NULL,'Serbia',NULL,'1234567890',NULL,'zeljko',3);
INSERT INTO customer VALUES (43,'Zeljko','Raznatovic','Arkanovci',NULL,'Erdut',NULL,'Serbia',NULL,'12345',NULL,'zeljko@raznatovic',3);
START TRANSACTION;
INSERT INTO customer VALUES (43,'Zeljko','Raznatovic','Arkanovci',NULL,'Erdut',NULL,'Serbia',NULL,'1234567890',NULL,'zeljko@raznatovic',3);
SELECT * FROM customer;
ROLLBACK;