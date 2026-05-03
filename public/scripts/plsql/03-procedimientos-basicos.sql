CREATE OR REPLACE
    PROCEDURE sp_saludar(vv_nombre VARCHAR2 DEFAULT ' Willie Colón')
/*
    Autor: David Caicedo
    Fecha: 23-02-2026
    Descripcion: SP que genera un saludo a alguien
*/
IS
    vv_mensaje_final VARCHAR2(100);
BEGIN
    vv_mensaje_final := 'Hola' || vv_nombre;
    dbms_output.put_line(vv_mensaje_final);
END;
/

BEGIN 
    sp_saludar(' Joe Arroyo');
END;
/

DROP PROCEDURE sp_saludar;

CREATE OR REPLACE
    PROCEDURE sp_ultimo_viernes(vn_numero_mes NUMBER)
/*
    Autor: David Caicedo
    Fecha: 23-02-2026
    Descripcion: Devuelve el último viernes del mes indicado
*/
IS
BEGIN
    SELECT NEXT_DAY(LAST_DAY(SYSDATE)-7, 'VIERNES') FROM DUAL;
END;
/
