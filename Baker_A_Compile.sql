/*******************************************************
* Damon Baker
* October 10th 2021
* extracts tables from syscatalog.
*******************************************************/


CREATE OR REPLACE FUNCTION Get_Constraint_Columns (
/*******************************************************
* Damon Baker
* October 10th 2021
* Returns the columns for the constraint name and table passed in. 
*******************************************************/
iConstraintName VARCHAR2,
iTableName IN User_tables.Table_Name%TYPE
)
--Return type 
RETURN VARCHAR
AS
  CURSOR ExtractedConstraintColumns IS
    SELECT Column_Name
      FROM User_Cons_Columns
      WHERE TABLE_NAME = iTableName
      AND Constraint_Name = iConstraintName
      ORDER BY Position;
  
  CURRENTROW ExtractedConstraintColumns%ROWTYPE;
  wConstraintColumns VARCHAR2(100);
  wComma VARCHAR2(8);
  
BEGIN
     wComma := '';
     FOR CURRENROW IN ExtractedConstraintColumns LOOP 
        wConstraintColumns := wConstraintColumns || wComma || CURRENROW.Column_Name;           
        wComma := ', ';     
      END LOOP;    
      
      RETURN wConstraintColumns;

END;
/
SHOW ERRORS


CREATE OR REPLACE PROCEDURE Extract_PK_Constraints (
/*******************************************************
* Damon Baker
* October 10th 2021
* Extracts the name of the primary key constraint from the passed in table.
*******************************************************/
iTableName IN User_tables.Table_Name%TYPE

)
AS
    NO_PK_DEFINED EXCEPTION;
    wPrimaryKeyColumns VARCHAR2(50);
    wPrimaryKeyName VARCHAR2(30);
    wPrimaryKeyCount VARCHAR2(30);
   
BEGIN
    DECLARE 
      NO_PK_DEFINED EXCEPTION;
      
    BEGIN
      SELECT COUNT(*)
      INTO wPrimaryKeyCount
      FROM User_Constraints   
      WHERE Table_Name = iTableName
      AND Constraint_type = 'P';

       IF wPrimaryKeyCount >0 THEN  
          SELECT constraint_name
            INTO wPrimaryKeyName
            FROM User_Constraints   
            WHERE Table_Name = iTableName
            AND Constraint_type = 'P';

        wPrimaryKeyColumns := Get_Constraint_Columns(wPrimaryKeyName, iTableName);
        DBMS_OUTPUT.PUT_LINE(', ' || 'CONSTRAINT ' || wPrimaryKeyName );
        DBMS_OUTPUT.PUT_LINE('    PRIMARY KEY(' || wPrimaryKeyColumns || ')' );
        
        ELSE                   
          RAISE NO_PK_DEFINED;
         END IF;

      EXCEPTION
        WHEN NO_PK_DEFINED THEN
        DBMS_OUTPUT.PUT_LINE('-- *** WARNING *** No Primary Key Defined');
      END;
END;
/
SHOW ERRORS


CREATE OR REPLACE PROCEDURE Extract_Check_Constraint (
/*******************************************************
* Damon Baker
* October 10th 2021
* Extracts the names of the check constraints from the passed in table. 
*******************************************************/
iTableName IN User_tables.Table_Name%TYPE

)
AS
    CURSOR ExtractedCheckConstraintNames IS 
      SELECT constraint_name, search_condition
        FROM User_Constraints   
        WHERE Table_Name = iTableName
        AND Constraint_type = 'C';
  
    CURRENTROW ExtractedCheckConstraintNames%ROWTYPE;
    wCheckColumns VARCHAR2(90);
    
BEGIN
    FOR CURRENTROW IN ExtractedCheckConstraintNames LOOP
       IF CURRENTROW.search_condition NOT LIKE '%" IS NOT NULL%' THEN
          wCheckColumns := Get_Constraint_Columns(CURRENTROW.constraint_name, iTableName);      
          DBMS_OUTPUT.PUT_LINE(', ' || 'CONSTRAINT ' || CURRENTROW.constraint_name );
          DBMS_OUTPUT.PUT_LINE('    CHECK (' || CURRENTROW.search_condition || ')' );
       END IF;
       END LOOP;
    
END;
/
SHOW ERRORS


CREATE OR REPLACE PROCEDURE Extract_Unique_Constraint (
/*******************************************************
* Damon Baker
* October 10th 2021
* Extracts the constraints name from the passed in table. 
*******************************************************/
iTableName IN User_tables.Table_Name%TYPE

)
AS
    CURSOR ExtractedUniqueConstraintNames IS 
      SELECT constraint_name
        FROM User_Constraints   
        WHERE Table_Name = iTableName
        AND Constraint_type = 'U';
  
    CURRENTROW ExtractedUniqueConstraintNames%ROWTYPE;
    wUniqueColumns VARCHAR2(50);
    WComma VARCHAR2(8);

BEGIN     
    FOR CURRENTROW IN ExtractedUniqueConstraintNames LOOP
          wUniqueColumns := Get_Constraint_Columns(CURRENTROW.constraint_name, iTableName);
          DBMS_OUTPUT.PUT_LINE(', ' || 'CONSTRAINT ' || CURRENTROW.constraint_name );
          DBMS_OUTPUT.PUT_LINE('    Unique(' || wUniqueColumns || ')' );
       END LOOP;
END;
/
SHOW ERRORS


CREATE OR REPLACE PROCEDURE Extract_FK_Constraint (
/*******************************************************
* Damon Baker
* October 10th 2021
* Extracts the constraints name from the passed in table. 
*******************************************************/
iTableName IN User_tables.Table_Name%TYPE

)
AS
    CURSOR ExtractedFK IS 
      SELECT constraint_name, R_Constraint_name, delete_rule
        FROM User_Constraints   
        WHERE Table_Name = iTableName
        AND Constraint_type = 'R';
  
    CURRENTROW ExtractedFK%ROWTYPE;
    wUniqueColumns VARCHAR2(50);
    wParentTable VARCHAR2(30);
    WComma VARCHAR2(8);

BEGIN 
  
    FOR CURRENTROW IN ExtractedFK LOOP  
        wUniqueColumns := Get_Constraint_Columns(CURRENTROW.constraint_name, iTableName);
        
        SELECT Table_Name
          INTO wParentTable
          FROM User_Constraints
          WHERE Constraint_Name = CURRENTROW.R_Constraint_Name;
        DBMS_OUTPUT.PUT_LINE('ALTER TABLE ' || iTableName);
        DBMS_OUTPUT.PUT_LINE('  ADD CONSTRAINT ' || CURRENTROW.constraint_name );
        DBMS_OUTPUT.PUT_LINE('      FOREIGN KEY (' || wUniqueColumns || ')' );
        DBMS_OUTPUT.PUT_LINE('      REFERENCES ' || wParentTable);
        DBMS_OUTPUT.PUT_LINE('      ON DELETE ' || CURRENTROW.delete_rule || ';' );
        DBMS_OUTPUT.PUT_LINE('--');

    END LOOP;
        
END;
/
SHOW ERRORS

CREATE OR REPLACE PROCEDURE Extract_Columns (
/*******************************************************
* Damon Baker
* October 10th 2021
* Extracts Columns from the database. 
*******************************************************/

  iTableName IN User_tables.Table_Name%TYPE
  
)
AS  
  CURSOR TableRows IS
    SELECT column_name, data_type, data_length, data_default, data_precision, data_scale, nullable
    FROM user_tab_columns
    WHERE table_name = iTableName
    ORDER BY Column_ID;
  CURRENTROW TableRows%ROWTYPE;
 
  wColumnName VARCHAR2(25);
  wDataType VARCHAR2(10);
  wDataLength VARCHAR2(20);
  wDataDefault VARCHAR2(50);
  wNullable VARCHAR2(10);
  wNotNull VARCHAR2(15);
  wComma VARCHAR2 (10);
  wOutput VARCHAR2(50);
    
BEGIN
  
  wComma := '  '; 
    
    FOR CURRENTROW IN TableRows LOOP                    
      wColumnName := CURRENTROW.column_name;
      wDataType := CURRENTROW.data_type;
      wDataLength := CURRENTROW.data_length; 
      wNullable := CURRENTROW.nullable;     
   
      -- Determines if it is NOT NULL 
        IF wNullable = 'N' THEN
           wNotNull := 'NOT NULL';
        ELSIF wNullable = 'Y' THEN
            wNotNull := '';
        END IF;
                 
        -- Determines the default date or set it to an empty string 
        IF CURRENTROW.data_default IS NULL THEN
          wDataDefault := '';
        ELSE 
          wDataDefault := 'DEFAULT ' || REPLACE(CURRENTROW.data_default, CHR(10), '');
        END IF;

      -- Determines the datatype
        CASE         
          WHEN wDataType = 'NUMBER' THEN
            wOutput := wDataType || '(' || CURRENTROW.data_precision || ',' || CURRENTROW.data_scale || ')';
          
          WHEN wDataType = 'CHAR' THEN  
            wOutput := wDataType || '(' || wDataLength || ')';
      
          WHEN wDataType = 'VARCHAR2' THEN
            wOutput := wDataType || '(' || wDataLength || ')';
        
          WHEN wDataType = 'DATE' THEN
          wOutput := wDataType;
          
          ELSE
          --the calling block handles the exception so its not declared here. 
              DBMS_OUTPUT.PUT_LINE( wComma || wColumnName|| RPAD(' ', 25 - LENGTH(wColumnName)) || wDataType );
            RAISE_APPLICATION_ERROR(-20100,'*** Unknown data type ' || wDataType || ' ***');
      
        END CASE;      
      
       DBMS_OUTPUT.PUT_LINE( wComma ||wColumnName || RPAD(' ', 25 - LENGTH(wColumnName)) || wOutput || RPAD(' ', 15 - (LENGTH(wOutput))) || TRIM(wDataDefault) || RPAD(' ', 35 - LENGTH(wNotNull))|| wNotNull);

        wComma := ', ';
        wDatatype := '';
        wOutput := '';             
        
      END LOOP;
    

END;
/
SHOW ERRORS

CREATE OR REPLACE PROCEDURE Get_Tables (
/*******************************************************
* Damon Baker
* October 10th 2021
* Extracts The tables from the database. 
*******************************************************/
iTable IN CHAR DEFAULT'%'

)
AS 
  CURSOR TableNames IS
    SELECT Table_Name 
    FROM User_Tables
    WHERE Table_Name LIKE UPPER(iTable)
    ORDER BY Table_Name;
  CURRENTROW TableNames%ROWTYPE;
  AssignNum CHAR(5) := 'V4.0';
  wCount NUMBER(3);
BEGIN

  DBMS_OUTPUT.PUT_LINE('---- Oracle Catalog Extract Utility ' || AssignNum || '----');
  DBMS_OUTPUT.PUT_LINE('----');
  DBMS_OUTPUT.PUT_LINE('---- Run on ' || TO_CHAR (SYSDATE, 'MON DD, YYYY ') || 'at ' || TO_CHAR (SYSDATE, 'HH24:MI'));
  DBMS_OUTPUT.PUT_LINE('----');
  DBMS_OUTPUT.PUT_LINE('---- S T A R T I N G  T A B L E  D R O P S');
  DBMS_OUTPUT.PUT_LINE('----');
  
  FOR CURRENTROW IN TableNames LOOP
     DBMS_OUTPUT.PUT_LINE('DROP TABLE ' ||  CURRENTROW.Table_Name || ';' );  
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('----');
  DBMS_OUTPUT.PUT_LINE('---- T A B L E  D R O P S  C O M P L E T E D');
  DBMS_OUTPUT.PUT_LINE('----');
  DBMS_OUTPUT.PUT_LINE('----');
  DBMS_OUTPUT.PUT_LINE('---- S T A R T I N G  T A B L E  C R E A T E');
  DBMS_OUTPUT.PUT_LINE('----');
  
  FOR CURRENTROW IN TableNames LOOP
    DECLARE
      INVALID_COLUMN_TYPE EXCEPTION;
      PRAGMA EXCEPTION_INIT(INVALID_COLUMN_TYPE, -20100);
    BEGIN   
      DBMS_OUTPUT.PUT_LINE('--   Start extracting table ' || CURRENTROW.Table_Name); 
      DBMS_OUTPUT.PUT_LINE('CREATE TABLE ' || CURRENTROW.Table_Name || ' (');
      
      Extract_Columns(CURRENTROW.Table_Name);
      Extract_PK_Constraints(CURRENTROW.Table_Name);
      Extract_Unique_Constraint(CURRENTROW.Table_Name);
      Extract_Check_Constraint(CURRENTROW.Table_Name);

      DBMS_OUTPUT.PUT_LINE(LPAD(')',LENGTH(CURRENTROW.Table_Name)+ 15 ) || '; -- END of table ' || CURRENTROW.Table_Name || ' creation' );
      DBMS_OUTPUT.PUT_LINE('--');
      DBMS_OUTPUT.PUT_LINE('--');

    EXCEPTION
     --Catching by Exception name so use when
      WHEN INVALID_COLUMN_TYPE THEN
       DBMS_OUTPUT.PUT_LINE('================================================================================'); 
       DBMS_OUTPUT.PUT_LINE('EXCEPTION ' || SQLCODE || ' Raised - ' || SQLERRM );
       DBMS_OUTPUT.PUT_LINE('Unable to complete table generation for ' || CURRENTROW.table_name);
       DBMS_OUTPUT.PUT_LINE('================================================================================');
       DBMS_OUTPUT.PUT_LINE(LPAD(')',LENGTH(CURRENTROW.Table_Name)+ 15 ) || '; -- END of table ' || CURRENTROW.Table_Name || ' creation' );
       DBMS_OUTPUT.PUT_LINE('--');
       DBMS_OUTPUT.PUT_LINE('--');
    END;
       
  END LOOP;
      DBMS_OUTPUT.PUT_LINE('----');
      DBMS_OUTPUT.PUT_LINE('---- T A B L E  C R E A T E  C O M P L E T E D');
      DBMS_OUTPUT.PUT_LINE('----');
      DBMS_OUTPUT.PUT_LINE('----'); 
      DBMS_OUTPUT.PUT_LINE('---- S T A R T I N G  T A B L E  A L T E R');
      DBMS_OUTPUT.PUT_LINE('----');
      
  
    FOR CURRENTROW IN TableNames LOOP
      SELECT COUNT(*)
        INTO wCount
        FROM User_Constraints   
        WHERE Table_Name = CURRENTROW.Table_name
        AND Constraint_type = 'R';
      
      IF wCount >0 THEN
        DBMS_OUTPUT.PUT_LINE('--');
        DBMS_OUTPUT.PUT_LINE('--');
        DBMS_OUTPUT.PUT_LINE('-- Start Alter of table ' || CURRENTROW.Table_Name);  
        Extract_FK_Constraint(CURRENTROW.Table_Name);
        DBMS_OUTPUT.PUT_LINE('-- End of Alter table ' || CURRENTROW.Table_Name);
      END IF;
    
     END LOOP;
      
      DBMS_OUTPUT.PUT_LINE('----');
      DBMS_OUTPUT.PUT_LINE('---- T A B L E  A L T E R  C O M P L E T E');
      DBMS_OUTPUT.PUT_LINE('----'); 

  
  DBMS_OUTPUT.PUT_LINE('---- Oracle Catalog Extract Utility ' || AssignNum || '----');
  DBMS_OUTPUT.PUT_LINE('---- Run completed on ' || TO_CHAR (SYSDATE, 'MON DD, YYYY ') || 'at ' || TO_CHAR (SYSDATE, 'HH24:MI'));

END;
/
SHOW ERRORS
EXIT
 


   







