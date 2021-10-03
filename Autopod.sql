DROP DATABASE IF EXISTS ADB;
CREATE DATABASE ADB;
USE ADB;

CREATE TABLE CUSTOMER
	(id		INT		NOT NULL,
     name	VARCHAR(100)	NOT NULL,
     email	VARCHAR(100)	NOT NULL,
     `credit-card` CHAR(16)	NOT NULL,
     PRIMARY KEY(id));
     
CREATE TABLE AUTOPOD
	(ain	CHAR(10)	NOT NULL,
     model	VARCHAR(64)	NOT NULL,
     color	VARCHAR(16)	NOT NULL,
     year	INT		NOT NULL,
     PRIMARY KEY(ain));
     
CREATE TABLE DOCK
	(dockcode	CHAR(6)	NOT NULL,
     location	VARCHAR(64)	NOT NULL,
     capacity	INT		NOT NULL,
     PRIMARY KEY(dockcode));
     
CREATE TABLE AVAILABLE
	(ain	CHAR(10)	NOT NULL,
     dockcode	CHAR(6)	NOT NULL,
     PRIMARY KEY(ain, dockcode),
     FOREIGN KEY(ain) REFERENCES AUTOPOD(ain)
     ON DELETE CASCADE,
     FOREIGN KEY(dockcode) REFERENCES DOCK(dockcode));

CREATE TABLE RENTAL
	(ain	CHAR(10)	NOT NULL,
     custid	INT		NOT NULL,
     origdc	CHAR(6)		NOT NULL,
     renttime	DATETIME	NOT NULL,
     PRIMARY KEY(ain, custid, renttime),
     FOREIGN KEY(ain) REFERENCES AUTOPOD(ain)
     ON DELETE CASCADE,
     FOREIGN KEY(custid) REFERENCES CUSTOMER(id),
     FOREIGN KEY(origdc) REFERENCES DOCK(dockcode));
     
CREATE TABLE COMPLETEDRENTAL
	(ain	CHAR(10)	NOT NULL,
     custid		INT		NOT NULL,
     inittime	DATETIME	NOT NULL,
     endtime	DATETIME	NOT NULL,
     origdc		CHAR(6)		NOT NULL,
     destdc		CHAR(6)		NOT NULL,
     cost		DECIMAL(10,2)	NOT NULL CHECK(cost >= 0),
     PRIMARY KEY(ain, custid, inittime),
     FOREIGN KEY(ain) REFERENCES AUTOPOD(ain)
     ON DELETE CASCADE,
     FOREIGN KEY(custid) REFERENCES CUSTOMER(id),
     FOREIGN KEY(origdc) REFERENCES DOCK(dockcode),
     FOREIGN KEY(destdc) REFERENCES DOCK(dockcode));

# TRIGGER a
DELIMITER &&
CREATE TRIGGER after_autopod_insert
AFTER INSERT ON AUTOPOD
FOR EACH ROW 
BEGIN
    IF EXISTS (SELECT DOCK.dockcode, capacity - COUNT(AVAILABLE.ain) AS OPENSLOT
				FROM (DOCK LEFT JOIN AVAILABLE ON DOCK.dockcode=AVAILABLE.dockcode)
				GROUP BY DOCK.dockcode, capacity
				HAVING capacity - COUNT(AVAILABLE.ain) > 0
				ORDER BY OPENSLOT DESC
				LIMIT 1)
		THEN INSERT INTO AVAILABLE
			VALUES
		(NEW.ain, (SELECT dockcode
					FROM (SELECT DOCK.dockcode, capacity - COUNT(AVAILABLE.ain) AS OPENSLOT
					FROM (DOCK LEFT JOIN AVAILABLE ON DOCK.dockcode=AVAILABLE.dockcode)
					GROUP BY DOCK.dockcode, capacity
					HAVING capacity - COUNT(AVAILABLE.ain) > 0
					ORDER BY OPENSLOT DESC
					LIMIT 1) AS T1));
	ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT="All dock capacities are reached.";
	END IF;
END &&
DELIMITER ;

# TRIGGER b
DELIMITER &&
CREATE TRIGGER del_autopod
BEFORE DELETE ON AUTOPOD
FOR EACH ROW
BEGIN
	IF EXISTS (SELECT ain
			   FROM RENTAL
			   WHERE ain=OLD.ain)
		THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT="AUTOPOD is rented and cannot be deleted.";
    END IF;
END &&
DELIMITER ;

# TRIGGER c
DELIMITER &&
CREATE PROCEDURE StartRental(IN AutoID CHAR(10), IN CustomID INT)
BEGIN
	IF NOT EXISTS (SELECT ain 
			   FROM AUTOPOD
               WHERE ain=AutoID)
	OR NOT EXISTS (SELECT id 
			    FROM CUSTOMER
                WHERE id = CustomID)
		THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT="Incorrect CustID or AIN";
	END IF;
    
    IF EXISTS (SELECT ain 
			   FROM AVAILABLE
               WHERE ain=AutoID)

        THEN INSERT INTO RENTAL
			VALUES
		(AutoID, CustomID, (SELECT dockcode
							FROM AVAILABLE NATURAL JOIN AUTOPOD
                            WHERE ain=AutoID), now());
		DELETE FROM AVAILABLE
					WHERE AVAILABLE.ain=AutoID;
	ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT="AUTOPOD not available";
	END IF;
END &&
DELIMITER ;

# TRIGGER d
DELIMITER &&
CREATE PROCEDURE EndRental(IN AutoID CHAR(10), IN CustomID INT, 
						   IN DestDock CHAR(6), IN Price DECIMAL(10,2))
BEGIN
	IF EXISTS (SELECT A.ain, id
			   FROM AUTOPOD NATURAL JOIN RENTAL AS A,
                    CUSTOMER JOIN RENTAL AS B ON id=CustID 
               WHERE A.ain=AutoID AND id=CustomID AND A.renttime=B.renttime)
	
		THEN IF EXISTS (SELECT dockcode, capacity, COUNT(*), capacity- COUNT(*)
						FROM AVAILABLE NATURAL JOIN DOCK
                        WHERE dockcode = DestDock
						GROUP BY dockcode, capacity
						HAVING capacity - COUNT(*) = 0)
                        
				THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT="Dock capacity is reached.";
			ELSE 
            INSERT INTO COMPLETEDRENTAL
						VALUES
					(AutoID, CustomID, (SELECT renttime
										FROM RENTAL
										WHERE ain=AutoID AND custid=CustomID), now(),
										(SELECT origdc
										FROM RENTAL
										WHERE ain=AutoID AND custid=CustomID), DestDock, Price);
                
					DELETE FROM RENTAL
					WHERE RENTAL.ain=AutoID AND RENTAL.custid=CustomID;
                
                    INSERT INTO AVAILABLE
						VALUES
					(AutoID, DestDock);
            END IF;
	ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT="Rental does not exist.";
    END IF;
END&&
DELIMITER ;