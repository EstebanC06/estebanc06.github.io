DECLARE 
    exc_pais EXCEPTION;
    vc_pais COUNTRIES.COUNTRY_NAME%TYPE;
BEGIN
    SELECT COUNTRY_NAME INTO vc_pais 
    FROM COUNTRIES WHERE COUNTRY_NAME = 'Bogotá'; 
    IF vc_pais = 'Bogotá' THEN 
        RAISE exc_pais;
    END IF;
EXCEPTION
    WHEN exc_pais THEN 
        DBMS_OUTPUT.PUT_LINE('Pais detectado no se encuentra');
END;
/
