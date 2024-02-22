--%%%%%%%%%%%%%%%%%%---KREIRANJE BAZE I TABLICA---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CREATE DATABASE knjiznica_
GO
USE knjiznica_

CREATE TABLE clanovi (
	ID_clana				INT			IDENTITY(1000,99) PRIMARY KEY,
	ime_clana				VARCHAR(25)	NOT NULL,
	prezime_clana			VARCHAR(25)	NOT NULL,
	datumRodenja_clana		DATE,
	email_clana				VARCHAR(30),
	brojTelefona_clana		VARCHAR(30),	
	mjestoStanovanja_clana	VARCHAR(25),
	adresaStanovanja_clana	VARCHAR(50),
	postanskiBroj_clana		INT,
	datumUclanjenja_clana	DATE		NOT NULL
) 

CREATE TABLE katalog (
	ID_knjige				INT			IDENTITY(1000,19) PRIMARY KEY,
	ISBN_knjige				VARCHAR(30)	NOT NULL,
	ime_autor_knjige		VARCHAR(50),
	prezime_autor_knjige	VARCHAR(50),
	naslov_knjige			VARCHAR(70),
	godinaIzdanja_knjige	INT,
	izdavac_knjige			VARCHAR(30)
)

CREATE TABLE posudba (
	ID_clana			INT		NOT NULL	FOREIGN KEY REFERENCES clanovi(ID_clana),
	ID_knjige			INT		NOT NULL	FOREIGN KEY	REFERENCES katalog(ID_knjige),
	datum_posudbe		DATE,
	datum_povratka		DATE,

	CONSTRAINT pk_posudba PRIMARY KEY (ID_clana, ID_knjige)
)
ALTER TABLE posudba ADD CONSTRAINT default_date DEFAULT GETDATE() FOR datum_posudbe




--%%%%%%%%%%%%%%%%%%---PUNJENJE TABLICA---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- PUNJENJE TABLICE clanovi
BULK INSERT [knjiznica].[dbo].[clanovi]
FROM 'C:\Users\ivank\Documents\data_knjiznica\mockdata_members.csv'
WITH (
    FIELDTERMINATOR = ',',
	--ROWTERMINATOR = '\r\n',
	BATCHSIZE = 1,
    FIRSTROW = 2,
	ERRORFILE ='C:\Users\ivank\Documents\data_knjiznica\mockdata_members_ERROR.csv'
) 
--Unos datuma uèlanjenja
UPDATE		clanovi
SET			datumUclanjenja_clana = DATEADD(DAY,ABS(CHECKSUM(NEWID()))%DATEDIFF(DAY,datumRodenja_clana,GETDATE()),datumRodenja_clana)



--- PUNJENJE TABLICE katalog
BULK INSERT [knjiznica].[dbo].[katalog]
FROM 'C:\Users\ivank\Documents\data_knjiznica\mockdata_books.csv'
WITH (
    FIELDTERMINATOR = ',',
	--ROWTERMINATOR = '\r\n',
	BATCHSIZE = 1,
    FIRSTROW = 2,
	ERRORFILE ='C:\Users\ivank\Documents\data_knjiznica\mockdata_books_ERROR.csv'
) 


-- PUNJENJE TABLICE posudba
-- Priprema tablice
WITH CTE1 AS
(
    SELECT ROW_NUMBER() OVER(ORDER BY ID_clana) AS ROWNUM, * FROM clanovi
),
CTE2 AS
(
    SELECT ROW_NUMBER() OVER (ORDER BY ID_knjige) AS ROWNUM, * FROM katalog
)
SELECT		ID_clana, 
			ID_knjige
INTO		#tmp_posudba
FROM		CTE1 
LEFT JOIN	CTE2 
ON			CTE1.ROWNUM = CTE2.ROWNUM

--Punjenje tablice
INSERT			posudba(ID_clana, ID_knjige)
SELECT TOP(200)	ID_clana,
				ID_knjige
FROM			#tmp_posudba
WHERE			ID_knjige IS NOT NULL
ORDER BY		NEWID()


--%%%%%%%%%%%%%%%%%%---UPITI---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-- Knjige koje su slobodne za posudbu

CREATE VIEW	view_popis_graðe	AS
SELECT		naslov_knjige, 
			ime_autor_knjige,
			prezime_autor_knjige
FROM		katalog
LEFT JOIN	posudba
ON			katalog.ID_knjige = posudba.ID_knjige
WHERE		posudba.datum_posudbe IS NULL


-- Prebacivanje neaktivnih èlanova u zasebnu tablicu

CREATE PROCEDURE neaktivni_èlanovi	AS
BEGIN

CREATE TABLE neaktivni (
	ID_clana				INT			PRIMARY KEY,
	ime_clana				VARCHAR(25)	NOT NULL,
	prezime_clana			VARCHAR(25)	NOT NULL,
	datumRodenja_clana		DATE,
	email_clana				VARCHAR(30),
	brojTelefona_clana		VARCHAR(30),	
	mjestoStanovanja_clana	VARCHAR(25),
	adresaStanovanja_clana	VARCHAR(50),
	postanskiBroj_clana		INT,
	datumUclanjenja_clana	DATE		NOT NULL
) 

INSERT INTO neaktivni
SELECT	*
FROM	clanovi
WHERE	ID_clana
NOT IN	(
		SELECT		ID_clana
		FROM		posudba
		)
--ALTER TABLE neaktivni ADD CONSTRAINT ID_clana PRIMARY KEY (ID_clana)

DELETE
FROM	clanovi
WHERE	ID_clana
IN		(
		SELECT	ID_clana
		FROM	neaktivni
		)
END



-- Okidaè koji ne dopušta brisanje iz tablice posudba_knjige
CREATE TRIGGER TRIGGER_brisanje_posudba
ON				posudba
INSTEAD OF DELETE
AS
PRINT			'Nije dopušteno brisati podatke iz tablice!'



--Kreiranje prijavnog naloga za korisnika Ivica
USE master
GO
CREATE LOGIN			Ivica
WITH PASSWORD		=	'Pa$$w0rd',
DEFAULT_DATABASE	=	knjiznica_,
CHECK_EXPIRATION	=	ON,
CHECK_POLICY		=	ON

--Kreiranje korisnièkog raèuna za korisnika Ivica i dodjela uloge db_datawriter
USE knjiznica_
GO
CREATE USER		Ivica
FOR LOGIN		Ivica
ALTER ROLE db_datawriter
ADD MEMBER Ivica


--Kreiranje backup-a pod imenom knjiznica_bkp.bak
EXEC sp_addumpdevice 'disk', 'knjiznica_bkp', 'C:\Backup\knjiznica_bkp.bak'
USE master
BACKUP DATABASE knjiznica_ TO knjiznica_bkp
