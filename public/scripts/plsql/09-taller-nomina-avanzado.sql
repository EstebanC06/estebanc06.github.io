
-- TALLER AVANZADO PL/SQL — SISTEMA DE LIQUIDACIÓN DE NÓMINA
-- Universidad El Bosque — Bases de Datos 2
--------------------------------------------------------------------

-- PUNTO 1 — Bloque anónimo: Liquidación individual
--------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED;



DECLARE
    
    v_id_empleado       EMPLEADOS.id_empleado%TYPE      := 1006;
    v_nombre            EMPLEADOS.nombre%TYPE;
    v_tipo_contrato     EMPLEADOS.tipo_contrato%TYPE;
    v_salario_base      EMPLEADOS.salario_base%TYPE;
    v_fecha_ingreso     EMPLEADOS.fecha_ingreso%TYPE;
    v_cod_sede          EMPLEADOS.cod_sede%TYPE;
    v_estado            EMPLEADOS.estado%TYPE;

    -- Variables de cálculo
    v_id_quincena       VARCHAR2(15) := '2026-Q1-ENE';
    v_salario_base_q    NUMBER(12,2) := 0;
    v_recargos          NUMBER(12,2) := 0;
    v_bonificacion      NUMBER(12,2) := 0;
    v_subtotal          NUMBER(12,2) := 0;
    v_antiguedad        NUMBER(5)    := 0;
    v_valor_hora        NUMBER(12,4) := 0;
    v_num_sanciones     NUMBER(5)    := 0;

    -- Parámetros leídos de tabla
    v_ret_servicios     NUMBER(5,2);
    v_rec_nocturno      NUMBER(5,2);
    v_rec_dominical     NUMBER(5,2);
    v_rec_noct_dom      NUMBER(5,2);
    v_nombre_sede       SEDES.nombre_sede%TYPE;

    -- Cursor explícito para horas trabajadas
    CURSOR cur_horas(p_id_empleado NUMBER, p_id_quincena VARCHAR2) IS
        SELECT tipo_hora, cantidad_horas
        FROM   HORAS_TRABAJADAS
        WHERE  id_empleado = p_id_empleado
        AND    id_quincena = p_id_quincena;

    r_hora cur_horas%ROWTYPE;

BEGIN
    -- Leer datos del empleado
    SELECT id_empleado, nombre, tipo_contrato, salario_base,
           fecha_ingreso, cod_sede, estado
    INTO   v_id_empleado, v_nombre, v_tipo_contrato, v_salario_base,
           v_fecha_ingreso, v_cod_sede, v_estado
    FROM   EMPLEADOS
    WHERE  id_empleado = v_id_empleado;

    -- Leer nombre de sede
    SELECT nombre_sede INTO v_nombre_sede FROM SEDES WHERE cod_sede = v_cod_sede;

    -- Leer parámetros de porcentajes
    SELECT valor_numerico INTO v_ret_servicios   FROM PARAMETROS WHERE cod_parametro = 'RET_SERVICIOS';
    SELECT valor_numerico INTO v_rec_nocturno    FROM PARAMETROS WHERE cod_parametro = 'RECARGO_NOCTURNO';
    SELECT valor_numerico INTO v_rec_dominical   FROM PARAMETROS WHERE cod_parametro = 'RECARGO_DOMINICAL';
    SELECT valor_numerico INTO v_rec_noct_dom    FROM PARAMETROS WHERE cod_parametro = 'RECARGO_NOCT_DOM';

    -- Calcular antigüedad en años
    v_antiguedad := TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_ingreso) / 12);

    -- REGLA 1: Salario base quincenal según tipo de contrato
    IF v_tipo_contrato = 'PLANTA' THEN
        v_salario_base_q := v_salario_base / 2;
        v_valor_hora     := v_salario_base / 240;

    ELSIF v_tipo_contrato = 'TEMPORAL' THEN
        -- Base = valor_hora x horas normales
        SELECT NVL(SUM(CASE WHEN tipo_hora = 'NORMAL' THEN cantidad_horas ELSE 0 END), 0)
        INTO   v_salario_base_q
        FROM   HORAS_TRABAJADAS
        WHERE  id_empleado = v_id_empleado
        AND    id_quincena = v_id_quincena;
        v_salario_base_q := v_salario_base * v_salario_base_q;
        v_valor_hora     := v_salario_base; -- ya es valor por hora

    ELSIF v_tipo_contrato = 'SERVICIOS' THEN
        v_salario_base_q := (v_salario_base - (v_salario_base * v_ret_servicios / 100)) / 2;
        v_valor_hora     := 0;
    END IF;

    -- REGLA 2: Recargos (solo PLANTA y TEMPORAL)
    IF v_tipo_contrato != 'SERVICIOS' THEN
        OPEN cur_horas(v_id_empleado, v_id_quincena);
        LOOP
            FETCH cur_horas INTO r_hora;
            EXIT WHEN cur_horas%NOTFOUND;

            IF r_hora.tipo_hora = 'NOCTURNA' THEN
                v_recargos := v_recargos + (r_hora.cantidad_horas * v_valor_hora * v_rec_nocturno / 100);
            ELSIF r_hora.tipo_hora = 'DOMINICAL' THEN
                v_recargos := v_recargos + (r_hora.cantidad_horas * v_valor_hora * v_rec_dominical / 100);
            ELSIF r_hora.tipo_hora = 'NOCTURNA_DOM' THEN
                v_recargos := v_recargos + (r_hora.cantidad_horas * v_valor_hora * v_rec_noct_dom / 100);
            END IF;
        END LOOP;
        CLOSE cur_horas;
    END IF;

    -- REGLA 3: Bonificación por antigüedad 
    IF v_tipo_contrato != 'SERVICIOS' THEN
        -- Verificar sanciones en últimos 6 meses
        SELECT COUNT(*) INTO v_num_sanciones
        FROM   SANCIONES
        WHERE  id_empleado = v_id_empleado
        AND    fecha_sancion >= ADD_MONTHS(SYSDATE, -6);

        IF v_num_sanciones > 2 THEN
            v_bonificacion := 0; -- Pierde bonificación
        ELSE
            v_bonificacion := CASE
                WHEN v_antiguedad BETWEEN 3 AND 5   THEN v_salario_base_q * 0.03
                WHEN v_antiguedad BETWEEN 6 AND 10  THEN v_salario_base_q * 0.06
                WHEN v_antiguedad > 10              THEN v_salario_base_q * 0.10
                ELSE 0
            END;
        END IF;
    END IF;

    -- Subtotal 
    v_subtotal := v_salario_base_q + v_recargos + v_bonificacion;

 
    DBMS_OUTPUT.PUT_LINE('=== LIQUIDACIÓN QUINCENAL ===');
    DBMS_OUTPUT.PUT_LINE('Empleado:         ' || v_nombre || ' (' || v_id_empleado || ')');
    DBMS_OUTPUT.PUT_LINE('Sede:             ' || v_nombre_sede);
    DBMS_OUTPUT.PUT_LINE('Tipo contrato:    ' || v_tipo_contrato);
    DBMS_OUTPUT.PUT_LINE('Antigüedad:       ' || v_antiguedad || ' años');
    DBMS_OUTPUT.PUT_LINE('-----------------------------');
    DBMS_OUTPUT.PUT_LINE('Salario base Q:   ' || TO_CHAR(v_salario_base_q, 'FM9,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('Recargos:         ' || TO_CHAR(v_recargos,       'FM9,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('Bonificación:     ' || TO_CHAR(v_bonificacion,   'FM9,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('-----------------------------');
    DBMS_OUTPUT.PUT_LINE('SUBTOTAL:         ' || TO_CHAR(v_subtotal, 'FM9,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('=============================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Empleado ' || v_id_empleado || ' no encontrado.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR inesperado: ' || SQLERRM);
END;
/


-- PUNTO 2 — Funciones standalone encadenadas
-------------------------------------------------------------------

-- 2.1 fn_salario_base_q
CREATE OR REPLACE FUNCTION fn_salario_base_q(
    p_id_empleado NUMBER,
    p_id_quincena VARCHAR2
) 
/*
    Autores: David Caicedo y Nicolas Zambrano
    Fecha: 20-04-2026
    Descripcion: SP que genera la liquidacion de un empleado
*/
RETURN NUMBER IS
    v_tipo   EMPLEADOS.tipo_contrato%TYPE;
    v_sal    EMPLEADOS.salario_base%TYPE;
    v_horas  NUMBER := 0;
    v_ret    NUMBER;
BEGIN
    SELECT tipo_contrato, salario_base INTO v_tipo, v_sal
    FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;

    IF v_tipo = 'PLANTA' THEN
        RETURN v_sal / 2;
    ELSIF v_tipo = 'TEMPORAL' THEN
        BEGIN
            SELECT NVL(cantidad_horas, 0) INTO v_horas
            FROM   HORAS_TRABAJADAS
            WHERE  id_empleado = p_id_empleado
            AND    id_quincena = p_id_quincena
            AND    tipo_hora   = 'NORMAL';
        EXCEPTION WHEN NO_DATA_FOUND THEN v_horas := 0;
        END;
        RETURN v_sal * v_horas;
    ELSIF v_tipo = 'SERVICIOS' THEN
        SELECT valor_numerico INTO v_ret
        FROM   PARAMETROS WHERE cod_parametro = 'RET_SERVICIOS';
        RETURN (v_sal - (v_sal * v_ret / 100)) / 2;
    END IF;
    RETURN 0;
END fn_salario_base_q;
/

-- 2.2 fn_recargos
CREATE OR REPLACE FUNCTION fn_recargos(
    p_id_empleado NUMBER,
    p_id_quincena VARCHAR2
) 
/*
    Autores: David Caicedo y Nicolas Zambrano
    Fecha: 20-04-2026
    Descripcion: fn
*/
RETURN NUMBER IS
    v_tipo  EMPLEADOS.tipo_contrato%TYPE;
    v_sal   EMPLEADOS.salario_base%TYPE;
    v_vh    NUMBER;
    v_total NUMBER := 0;
    v_rn    NUMBER; v_rd NUMBER; v_rnd NUMBER;
BEGIN
    SELECT tipo_contrato, salario_base INTO v_tipo, v_sal
    FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;

    IF v_tipo = 'SERVICIOS' THEN RETURN 0; END IF;

    SELECT valor_numerico INTO v_rn  FROM PARAMETROS WHERE cod_parametro = 'RECARGO_NOCTURNO';
    SELECT valor_numerico INTO v_rd  FROM PARAMETROS WHERE cod_parametro = 'RECARGO_DOMINICAL';
    SELECT valor_numerico INTO v_rnd FROM PARAMETROS WHERE cod_parametro = 'RECARGO_NOCT_DOM';

    v_vh := CASE v_tipo WHEN 'PLANTA' THEN v_sal / 240 ELSE v_sal END;

    FOR r IN (SELECT tipo_hora, cantidad_horas FROM HORAS_TRABAJADAS
              WHERE id_empleado = p_id_empleado AND id_quincena = p_id_quincena) LOOP
        IF    r.tipo_hora = 'NOCTURNA'    THEN v_total := v_total + r.cantidad_horas * v_vh * (v_rn  / 100);
        ELSIF r.tipo_hora = 'DOMINICAL'   THEN v_total := v_total + r.cantidad_horas * v_vh * (v_rd  / 100);
        ELSIF r.tipo_hora = 'NOCTURNA_DOM' THEN v_total := v_total + r.cantidad_horas * v_vh * (v_rnd / 100);
        END IF;
    END LOOP;
    RETURN NVL(v_total, 0);
END fn_recargos;
/

-- 2.3 fn_bonificacion (llama a fn_salario_base_q, debe crearse después)
CREATE OR REPLACE FUNCTION fn_bonificacion(
    p_id_empleado NUMBER
) 
/*
    Autores: David Caicedo y Nicolas Zambrano
    Fecha: 20-04-2026
    Descripcion: SP que genera la liquidacion de un empleado
*/
RETURN NUMBER IS
    v_tipo      EMPLEADOS.tipo_contrato%TYPE;
    v_ingreso   EMPLEADOS.fecha_ingreso%TYPE;
    v_antiguedad NUMBER;
    v_sanciones  NUMBER;
    v_base_q     NUMBER;
    v_pct        NUMBER := 0;
BEGIN
    SELECT tipo_contrato, fecha_ingreso INTO v_tipo, v_ingreso
    FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;

    IF v_tipo = 'SERVICIOS' THEN RETURN 0; END IF;

    SELECT COUNT(*) INTO v_sanciones FROM SANCIONES
    WHERE  id_empleado  = p_id_empleado
    AND    fecha_sancion >= ADD_MONTHS(SYSDATE, -6);

    IF v_sanciones > 2 THEN RETURN 0; END IF;

    v_antiguedad := TRUNC(MONTHS_BETWEEN(SYSDATE, v_ingreso) / 12);

    v_pct := CASE
        WHEN v_antiguedad BETWEEN 3 AND 5  THEN 0.03
        WHEN v_antiguedad BETWEEN 6 AND 10 THEN 0.06
        WHEN v_antiguedad > 10             THEN 0.10
        ELSE 0
    END;

    -- Usar quincena del taller para obtener base
    v_base_q := fn_salario_base_q(p_id_empleado, '2026-Q1-ENE');
    RETURN v_base_q * v_pct;
END fn_bonificacion;
/

-- 2.4 fn_bruto; auxilio y bono sede se calculan dentro del package
CREATE OR REPLACE FUNCTION fn_bruto(
    p_id_empleado NUMBER,
    p_id_quincena VARCHAR2
) 
/*
    Autores: David Caicedo y Nicolas Zambrano
    Fecha: 20-04-2026
    Descripcion: SP que genera la liquidacion de un empleado
*/
RETURN NUMBER IS
    v_base_q     NUMBER;
    v_recargos   NUMBER;
    v_bonif      NUMBER;
BEGIN
    v_base_q   := fn_salario_base_q(p_id_empleado, p_id_quincena);
    v_recargos := fn_recargos(p_id_empleado, p_id_quincena);
    v_bonif    := fn_bonificacion(p_id_empleado);
    RETURN v_base_q + v_recargos + v_bonif;
END fn_bruto;
/


-- Validacion de la funcion 
SELECT fn_bruto(1001, '2026-Q1-ENE')FROM DUAL;
/


-- PUNTO 3 — Procedimiento con excepciones
----------------------------------------------------------------

SAVEPOINT sv_antes_del_procedure;


CREATE OR REPLACE PROCEDURE sp_liquidar_empleado(
    p_id_empleado NUMBER,
    p_id_quincena VARCHAR2
) 
/*
    Autores: David Caicedo y Nicolas Zambrano
    Fecha: 20-04-2026
    Descripcion: SP que genera la liquidacion de un empleado
*/
IS
    v_nombre         EMPLEADOS.nombre%TYPE;
    v_tipo_contrato  EMPLEADOS.tipo_contrato%TYPE;
    v_salario_base   EMPLEADOS.salario_base%TYPE;
    v_cod_sede       EMPLEADOS.cod_sede%TYPE;
    v_acepta_aporte  EMPLEADOS.acepta_aporte_vol%TYPE;
    v_estado         EMPLEADOS.estado%TYPE;

    v_salario_base_q  NUMBER(12,2) := 0;
    v_recargos        NUMBER(12,2) := 0;
    v_bonificacion    NUMBER(12,2) := 0;
    v_auxilio_transp  NUMBER(12,2) := 0;
    v_bono_sede       NUMBER(12,2) := 0;
    v_bruto           NUMBER(12,2) := 0;

    v_deduccion_salud    NUMBER(12,2) := 0;
    v_deduccion_pension  NUMBER(12,2) := 0;
    v_fondo_solidaridad  NUMBER(12,2) := 0;
    v_embargo            NUMBER(12,2) := 0;
    v_libranzas          NUMBER(12,2) := 0;
    v_aporte_voluntario  NUMBER(12,2) := 0;
    v_total_deducciones  NUMBER(12,2) := 0;
    v_neto               NUMBER(12,2) := 0;

    v_smlmv              NUMBER(12,2);
    v_aux_transporte     NUMBER(12,2);
    v_bono_clima_sma     NUMBER(12,2);
    v_aporte_vol_bog     NUMBER(12,2);
    v_pct_salud          NUMBER(5,2);
    v_pct_pension        NUMBER(5,2);
    v_pct_fondo          NUMBER(5,2);
    v_umbral_fondo_smlmv NUMBER(5,2);

    v_horas_normales     NUMBER(10,2) := 0;
    v_salario_mensual_equiv NUMBER(14,2) := 0;
    v_base_embargo       NUMBER(12,2) := 0;
    v_pct_embargo_total  NUMBER(7,2)  := 0;
    v_liq_count          NUMBER(5);
BEGIN
    -- Validación 1: que el empleado exista
    BEGIN
        SELECT nombre, tipo_contrato, salario_base, cod_sede, acepta_aporte_vol, estado
        INTO   v_nombre, v_tipo_contrato, v_salario_base, v_cod_sede, v_acepta_aporte, v_estado
        FROM   EMPLEADOS
        WHERE  id_empleado = p_id_empleado;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Empleado no encontrado: ' || p_id_empleado);
    END;

    -- Validación 2: que el empleado esté ACTIVO
    IF v_estado != 'ACTIVO' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Empleado no activo: estado = ' || v_estado);
    END IF;

    -- Validación 3: que no exista ya la liquidación
    SELECT COUNT(*) INTO v_liq_count
    FROM   LIQUIDACION
    WHERE  id_empleado = p_id_empleado
    AND    id_quincena = p_id_quincena;

    IF v_liq_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Liquidación ya existe para empleado ' || p_id_empleado ||
            ' quincena ' || p_id_quincena);
    END IF;

    -- Leer parámetros
    SELECT valor_numerico INTO v_smlmv             FROM PARAMETROS WHERE cod_parametro = 'SMLMV';
    SELECT valor_numerico INTO v_aux_transporte     FROM PARAMETROS WHERE cod_parametro = 'AUX_TRANSPORTE';
    SELECT valor_numerico INTO v_bono_clima_sma     FROM PARAMETROS WHERE cod_parametro = 'BONO_CLIMA_SMA';
    SELECT valor_numerico INTO v_aporte_vol_bog     FROM PARAMETROS WHERE cod_parametro = 'APORTE_VOL_BOG';
    SELECT valor_numerico INTO v_pct_salud          FROM PARAMETROS WHERE cod_parametro = 'PCT_SALUD';
    SELECT valor_numerico INTO v_pct_pension        FROM PARAMETROS WHERE cod_parametro = 'PCT_PENSION';
    SELECT valor_numerico INTO v_pct_fondo          FROM PARAMETROS WHERE cod_parametro = 'PCT_FONDO_SOLIDARIDAD';
    SELECT valor_numerico INTO v_umbral_fondo_smlmv FROM PARAMETROS WHERE cod_parametro = 'UMBRAL_FONDO_SMLMV';

    -- Calcular conceptos usando funciones del Punto 2
    v_salario_base_q := fn_salario_base_q(p_id_empleado, p_id_quincena);
    v_recargos       := fn_recargos(p_id_empleado, p_id_quincena);
    v_bonificacion   := fn_bonificacion(p_id_empleado);

    -- Regla 4: Auxilio de transporte
    IF v_tipo_contrato != 'SERVICIOS' THEN
        IF v_tipo_contrato = 'PLANTA' THEN
            v_salario_mensual_equiv := v_salario_base;
        ELSE
            SELECT NVL(SUM(cantidad_horas), 0)
            INTO   v_horas_normales
            FROM   HORAS_TRABAJADAS
            WHERE  id_empleado = p_id_empleado
            AND    id_quincena = p_id_quincena
            AND    tipo_hora   = 'NORMAL';
            v_salario_mensual_equiv := v_salario_base * v_horas_normales * 2;
        END IF;
        IF v_salario_mensual_equiv <= 2 * v_smlmv THEN
            v_auxilio_transp := v_aux_transporte / 2;
        END IF;
    END IF;

    -- Regla 5: Bonos por sede
    IF v_cod_sede = 'SMA' AND v_tipo_contrato != 'SERVICIOS' THEN
        v_bono_sede := v_bono_clima_sma;
    END IF;

    -- Regla 6: Bruto
    v_bruto := v_salario_base_q + v_recargos + v_bonificacion + v_auxilio_transp + v_bono_sede;

    -- Regla 7: Deducciones en orden
    -- 1. Salud
    v_deduccion_salud   := ROUND(v_bruto * v_pct_salud / 100, 2);
    -- 2. Pensión
    v_deduccion_pension := ROUND(v_bruto * v_pct_pension / 100, 2);
    -- 3. Fondo de solidaridad (solo si bruto mensual equiv > umbral × SMLMV)
    IF (v_bruto * 2) > (v_umbral_fondo_smlmv * v_smlmv) THEN
        v_fondo_solidaridad := ROUND(v_bruto * v_pct_fondo / 100, 2);
    END IF;
    -- 4. Embargo (sobre bruto - salud - pensión - fondo)
    v_base_embargo := v_bruto - v_deduccion_salud - v_deduccion_pension - v_fondo_solidaridad;
    SELECT NVL(SUM(porcentaje), 0) INTO v_pct_embargo_total
    FROM   EMBARGOS
    WHERE  id_empleado = p_id_empleado
    AND    estado      = 'ACTIVO';
    v_embargo := ROUND(v_base_embargo * v_pct_embargo_total / 100, 2);
    -- 5. Libranzas
    SELECT NVL(SUM(cuota_mensual) / 2, 0) INTO v_libranzas
    FROM   LIBRANZAS
    WHERE  id_empleado = p_id_empleado
    AND    estado      = 'ACTIVA';
    -- 6. Aporte voluntario (solo Bogotá y si acepta)
    IF v_cod_sede = 'BOG' AND v_acepta_aporte = 'S' THEN
        v_aporte_voluntario := v_aporte_vol_bog;
    END IF;

    v_total_deducciones := v_deduccion_salud + v_deduccion_pension + v_fondo_solidaridad
                         + v_embargo + v_libranzas + v_aporte_voluntario;

    -- Regla 8: Neto
    v_neto := v_bruto - v_total_deducciones;

    -- Caso especial: Neto negativo
    IF v_neto < 0 THEN
        -- Paso 1: Ajustar embargo a 0
        v_total_deducciones := v_total_deducciones - v_embargo;
        v_embargo := 0;
        v_neto    := v_bruto - v_total_deducciones;
        -- Paso 2: Si sigue negativo, ajustar libranzas a 0
        IF v_neto < 0 THEN
            v_total_deducciones := v_total_deducciones - v_libranzas;
            v_libranzas := 0;
            v_neto      := v_bruto - v_total_deducciones;
        END IF;
    END IF;

    -- Insertar en LIQUIDACION
    INSERT INTO LIQUIDACION (
        id_liquidacion, id_empleado, id_quincena,
        salario_base_q, recargos, bonificacion, auxilio_transp, bono_sede,
        bruto,
        deduccion_salud, deduccion_pension, fondo_solidaridad,
        embargo, libranzas, aporte_voluntario,
        total_deducciones, neto
    ) VALUES (
        SEQ_LIQUIDACION.NEXTVAL, p_id_empleado, p_id_quincena,
        v_salario_base_q, v_recargos, v_bonificacion, v_auxilio_transp, v_bono_sede,
        v_bruto,
        v_deduccion_salud, v_deduccion_pension, v_fondo_solidaridad,
        v_embargo, v_libranzas, v_aporte_voluntario,
        v_total_deducciones, v_neto
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_liquidar_empleado;
/

-- Validaciones
BEGIN
    sp_liquidar_empleado(9999, '2026-Q1-ENE');
END;
/

BEGIN
    sp_liquidar_empleado(1017, '2026-Q1-ENE');
END;
/

BEGIN
    sp_liquidar_empleado(1001, '2026-Q1-ENE');
END;
/
-- ============================================================
-- PUNTO 4 — Package PKG_NOMINA (Spec + Body)
-- ============================================================
-- Limpieza previa de tipos (por si se re-ejecuta el script)
BEGIN
    EXECUTE IMMEDIATE 'DROP TYPE t_lista_liq    FORCE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TYPE t_concepto_liq FORCE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE '
        CREATE OR REPLACE TYPE t_concepto_liq AS OBJECT (
            id_empleado       NUMBER(6),
            id_quincena       VARCHAR2(15),
            salario_base_q    NUMBER(12,2),
            recargos          NUMBER(12,2),
            bonificacion      NUMBER(12,2),
            auxilio_transp    NUMBER(12,2),
            bono_sede         NUMBER(12,2),
            bruto             NUMBER(12,2),
            deduccion_salud   NUMBER(12,2),
            deduccion_pension NUMBER(12,2),
            fondo_solidaridad NUMBER(12,2),
            embargo           NUMBER(12,2),
            libranzas         NUMBER(12,2),
            aporte_voluntario NUMBER(12,2),
            total_deducciones NUMBER(12,2),
            neto              NUMBER(12,2)
        )';
END;
/
 
BEGIN
    EXECUTE IMMEDIATE
        'CREATE OR REPLACE TYPE t_lista_liq AS TABLE OF t_concepto_liq';
END;
/
 
 
-- 4.1 Package Specification
CREATE OR REPLACE PACKAGE PKG_NOMINA AS
 
    -- Constante pública: SMLMV (se inicializa en el bloque BEGIN del body)
    gc_smlmv NUMBER;
 
    -- t_concepto_liq y t_lista_liq se definen a nivel de schema (arriba).
    -- Se reexportan aquí como subtipos para uso interno cómodo.
    -- El package referencia directamente los tipos de schema.
 
    -- Liquidar un solo empleado (sobrecarga 1)
    PROCEDURE sp_liquidar_quincena(
        p_id_empleado NUMBER,
        p_id_quincena VARCHAR2
    );
 
    -- Liquidar TODOS los activos (sobrecarga 2)
    PROCEDURE sp_liquidar_quincena(
        p_id_quincena VARCHAR2
    );
 
    -- Total neto de una sede para una quincena
    FUNCTION fn_total_nomina_sede(
        p_cod_sede    VARCHAR2,
        p_id_quincena VARCHAR2
    ) RETURN NUMBER;
 
    -- Función pipelined para reporte filtrable
    FUNCTION fn_reporte_nomina(
        p_cod_sede       VARCHAR2 DEFAULT NULL,
        p_tipo_contrato  VARCHAR2 DEFAULT NULL
    ) RETURN t_lista_liq PIPELINED;
 
END PKG_NOMINA;
/
 
 
-- 4.2 Package Body
CREATE OR REPLACE PACKAGE BODY PKG_NOMINA AS
 
    -- -------------------------------------------------------
    -- Tipo privado para registro de deducciones
    -- DEBE declararse aquí (sección de declaraciones del body),
    -- NO dentro ni entre subprogramas (causa PLS-00103)
    -- -------------------------------------------------------
    TYPE t_deducciones IS RECORD (
        deduccion_salud    NUMBER(12,2),
        deduccion_pension  NUMBER(12,2),
        fondo_solidaridad  NUMBER(12,2),
        embargo            NUMBER(12,2),
        libranzas          NUMBER(12,2),
        aporte_voluntario  NUMBER(12,2),
        total              NUMBER(12,2)
    );
 
    -- Colección interna con INDEX BY para uso en BULK COLLECT / FORALL
    -- (distinta de t_lista_liq de schema que es la usada por PIPELINED)
    TYPE t_lista_interna IS TABLE OF t_concepto_liq INDEX BY PLS_INTEGER;
 
    -- -------------------------------------------------------
    -- Caché de parámetros (variable privada de package)
    -- -------------------------------------------------------
    TYPE t_parametros_cache IS RECORD (
        smlmv             NUMBER(12,2),
        aux_transporte    NUMBER(12,2),
        pct_salud         NUMBER(5,2),
        pct_pension       NUMBER(5,2),
        pct_fondo         NUMBER(5,2),
        umbral_fondo_smlmv NUMBER(5,2),
        rec_nocturno      NUMBER(5,2),
        rec_dominical     NUMBER(5,2),
        rec_noct_dom      NUMBER(5,2),
        ret_servicios     NUMBER(5,2),
        bono_clima_sma    NUMBER(12,2),
        aporte_vol_bog    NUMBER(12,2)
    );
    g_params t_parametros_cache;
 
    -- -------------------------------------------------------
    -- Procedimiento privado de auditoría (Punto 8)
    -- -------------------------------------------------------
    PROCEDURE sp_log_nomina(
        p_operacion       VARCHAR2,
        p_detalle         VARCHAR2,
        p_empleados_ok    NUMBER DEFAULT 0,
        p_empleados_error NUMBER DEFAULT 0,
        p_monto_total     NUMBER DEFAULT 0
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO LOG_NOMINA (
            id_log, fecha_hora, operacion, usuario,
            detalle, empleados_ok, empleados_error, monto_total
        ) VALUES (
            SEQ_LOG.NEXTVAL, SYSTIMESTAMP, p_operacion, USER,
            p_detalle, p_empleados_ok, p_empleados_error, p_monto_total
        );
        COMMIT; -- Commit de la transacción autónoma
    END sp_log_nomina;
 
    -- -------------------------------------------------------
    -- Funciones privadas (equivalentes al Punto 2, ahora en el package)
    -- -------------------------------------------------------
 
    -- fn_salario_base_q privada
    FUNCTION fn_salario_base_q(
        p_id_empleado NUMBER,
        p_id_quincena VARCHAR2
    ) RETURN NUMBER IS
        v_tipo_contrato EMPLEADOS.tipo_contrato%TYPE;
        v_salario_base  EMPLEADOS.salario_base%TYPE;
        v_horas_normales NUMBER(10,2) := 0;
        v_resultado      NUMBER(12,2) := 0;
    BEGIN
        SELECT tipo_contrato, salario_base
        INTO   v_tipo_contrato, v_salario_base
        FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;
 
        IF v_tipo_contrato = 'PLANTA' THEN
            v_resultado := v_salario_base / 2;
        ELSIF v_tipo_contrato = 'TEMPORAL' THEN
            SELECT NVL(SUM(cantidad_horas), 0)
            INTO   v_horas_normales
            FROM   HORAS_TRABAJADAS
            WHERE  id_empleado = p_id_empleado
            AND    id_quincena = p_id_quincena
            AND    tipo_hora   = 'NORMAL';
            v_resultado := v_salario_base * v_horas_normales;
        ELSIF v_tipo_contrato = 'SERVICIOS' THEN
            v_resultado := (v_salario_base - (v_salario_base * g_params.ret_servicios / 100)) / 2;
        END IF;
        RETURN NVL(v_resultado, 0);
    END fn_salario_base_q;
 
    -- fn_recargos privada
    FUNCTION fn_recargos(
        p_id_empleado NUMBER,
        p_id_quincena VARCHAR2
    ) RETURN NUMBER IS
        v_tipo_contrato EMPLEADOS.tipo_contrato%TYPE;
        v_salario_base  EMPLEADOS.salario_base%TYPE;
        v_valor_hora    NUMBER(14,4) := 0;
        v_recargos      NUMBER(12,2) := 0;
 
        CURSOR cur_horas(p_emp NUMBER, p_quin VARCHAR2) IS
            SELECT tipo_hora, cantidad_horas
            FROM   HORAS_TRABAJADAS
            WHERE  id_empleado = p_emp
            AND    id_quincena = p_quin;
        r_hora cur_horas%ROWTYPE;
    BEGIN
        SELECT tipo_contrato, salario_base
        INTO   v_tipo_contrato, v_salario_base
        FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;
 
        IF v_tipo_contrato = 'SERVICIOS' THEN RETURN 0; END IF;
 
        v_valor_hora := CASE v_tipo_contrato
                            WHEN 'PLANTA'   THEN v_salario_base / 240
                            WHEN 'TEMPORAL' THEN v_salario_base
                        END;
 
        OPEN cur_horas(p_id_empleado, p_id_quincena);
        LOOP
            FETCH cur_horas INTO r_hora;
            EXIT WHEN cur_horas%NOTFOUND;
            IF r_hora.tipo_hora = 'NOCTURNA' THEN
                v_recargos := v_recargos + (r_hora.cantidad_horas * v_valor_hora * g_params.rec_nocturno / 100);
            ELSIF r_hora.tipo_hora = 'DOMINICAL' THEN
                v_recargos := v_recargos + (r_hora.cantidad_horas * v_valor_hora * g_params.rec_dominical / 100);
            ELSIF r_hora.tipo_hora = 'NOCTURNA_DOM' THEN
                v_recargos := v_recargos + (r_hora.cantidad_horas * v_valor_hora * g_params.rec_noct_dom / 100);
            END IF;
        END LOOP;
        CLOSE cur_horas;
        RETURN NVL(v_recargos, 0);
    END fn_recargos;
 
    -- fn_bonificacion privada
    FUNCTION fn_bonificacion(
        p_id_empleado NUMBER,
        p_id_quincena VARCHAR2
    ) RETURN NUMBER IS
        v_tipo_contrato  EMPLEADOS.tipo_contrato%TYPE;
        v_fecha_ingreso  EMPLEADOS.fecha_ingreso%TYPE;
        v_antiguedad     NUMBER(5);
        v_num_sanciones  NUMBER(5);
        v_salario_base_q NUMBER(12,2);
    BEGIN
        SELECT tipo_contrato, fecha_ingreso
        INTO   v_tipo_contrato, v_fecha_ingreso
        FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;
 
        IF v_tipo_contrato = 'SERVICIOS' THEN RETURN 0; END IF;
 
        v_antiguedad := TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_ingreso) / 12);
 
        SELECT COUNT(*) INTO v_num_sanciones
        FROM   SANCIONES
        WHERE  id_empleado  = p_id_empleado
        AND    fecha_sancion >= ADD_MONTHS(SYSDATE, -6);
 
        IF v_num_sanciones > 2 THEN RETURN 0; END IF;
 
        v_salario_base_q := fn_salario_base_q(p_id_empleado, p_id_quincena);
 
        RETURN CASE
            WHEN v_antiguedad BETWEEN 3 AND 5  THEN v_salario_base_q * 0.03
            WHEN v_antiguedad BETWEEN 6 AND 10 THEN v_salario_base_q * 0.06
            WHEN v_antiguedad > 10             THEN v_salario_base_q * 0.10
            ELSE 0
        END;
    END fn_bonificacion;
 
    -- -------------------------------------------------------
    -- Función privada: calcular todas las deducciones
    -- Retorna un registro t_deducciones (declarado al inicio del body)
    -- -------------------------------------------------------
    FUNCTION fn_deducciones(
        p_bruto       NUMBER,
        p_id_empleado NUMBER
    ) RETURN t_deducciones IS
        v_ded           t_deducciones;
        v_cod_sede      EMPLEADOS.cod_sede%TYPE;
        v_acepta_aporte EMPLEADOS.acepta_aporte_vol%TYPE;
        v_base_embargo  NUMBER(12,2);
        v_pct_embargo   NUMBER(7,2) := 0;
    BEGIN
        SELECT cod_sede, acepta_aporte_vol
        INTO   v_cod_sede, v_acepta_aporte
        FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;
 
        -- 1. Salud
        v_ded.deduccion_salud   := ROUND(p_bruto * g_params.pct_salud   / 100, 2);
        -- 2. Pensión
        v_ded.deduccion_pension := ROUND(p_bruto * g_params.pct_pension / 100, 2);
        -- 3. Fondo solidaridad
        IF (p_bruto * 2) > (g_params.umbral_fondo_smlmv * g_params.smlmv) THEN
            v_ded.fondo_solidaridad := ROUND(p_bruto * g_params.pct_fondo / 100, 2);
        ELSE
            v_ded.fondo_solidaridad := 0;
        END IF;
        -- 4. Embargo
        v_base_embargo := p_bruto - v_ded.deduccion_salud
                        - v_ded.deduccion_pension - v_ded.fondo_solidaridad;
        SELECT NVL(SUM(porcentaje), 0) INTO v_pct_embargo
        FROM   EMBARGOS
        WHERE  id_empleado = p_id_empleado AND estado = 'ACTIVO';
        v_ded.embargo := ROUND(v_base_embargo * v_pct_embargo / 100, 2);
        -- 5. Libranzas
        SELECT NVL(SUM(cuota_mensual) / 2, 0) INTO v_ded.libranzas
        FROM   LIBRANZAS
        WHERE  id_empleado = p_id_empleado AND estado = 'ACTIVA';
        -- 6. Aporte voluntario
        v_ded.aporte_voluntario := 0;
        IF v_cod_sede = 'BOG' AND v_acepta_aporte = 'S' THEN
            v_ded.aporte_voluntario := g_params.aporte_vol_bog;
        END IF;
 
        v_ded.total := v_ded.deduccion_salud + v_ded.deduccion_pension
                     + v_ded.fondo_solidaridad + v_ded.embargo
                     + v_ded.libranzas + v_ded.aporte_voluntario;
        RETURN v_ded;
    END fn_deducciones;
 
    -- -------------------------------------------------------
    -- Función privada auxiliar: calcular registro completo de liquidación
    -- -------------------------------------------------------
    FUNCTION calcular_liquidacion(
        p_id_empleado NUMBER,
        p_id_quincena VARCHAR2
    ) RETURN t_concepto_liq IS
        -- Inicializar objeto con constructor (atributos Object Type no se auto-inicializan)
        v_rec           t_concepto_liq := t_concepto_liq(
                            p_id_empleado, p_id_quincena,
                            0,0,0,0,0,   -- salario_base_q, recargos, bonificacion, auxilio_transp, bono_sede
                            0,           -- bruto
                            0,0,0,       -- deduccion_salud, deduccion_pension, fondo_solidaridad
                            0,0,0,       -- embargo, libranzas, aporte_voluntario
                            0,0          -- total_deducciones, neto
                         );
        v_tipo_contrato EMPLEADOS.tipo_contrato%TYPE;
        v_salario_base  EMPLEADOS.salario_base%TYPE;
        v_cod_sede      EMPLEADOS.cod_sede%TYPE;
        v_ded           t_deducciones;
        v_horas_normales    NUMBER(10,2) := 0;
        v_salario_mensual_equiv NUMBER(14,2) := 0;
    BEGIN
        SELECT tipo_contrato, salario_base, cod_sede
        INTO   v_tipo_contrato, v_salario_base, v_cod_sede
        FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;
 
        v_rec.id_empleado    := p_id_empleado;
        v_rec.id_quincena    := p_id_quincena;
        v_rec.salario_base_q := fn_salario_base_q(p_id_empleado, p_id_quincena);
        v_rec.recargos       := fn_recargos(p_id_empleado, p_id_quincena);
        v_rec.bonificacion   := fn_bonificacion(p_id_empleado, p_id_quincena);
 
        -- Auxilio de transporte
        v_rec.auxilio_transp := 0;
        IF v_tipo_contrato != 'SERVICIOS' THEN
            IF v_tipo_contrato = 'PLANTA' THEN
                v_salario_mensual_equiv := v_salario_base;
            ELSE
                SELECT NVL(SUM(cantidad_horas), 0)
                INTO   v_horas_normales
                FROM   HORAS_TRABAJADAS
                WHERE  id_empleado = p_id_empleado
                AND    id_quincena = p_id_quincena
                AND    tipo_hora   = 'NORMAL';
                v_salario_mensual_equiv := v_salario_base * v_horas_normales * 2;
            END IF;
            IF v_salario_mensual_equiv <= 2 * g_params.smlmv THEN
                v_rec.auxilio_transp := g_params.aux_transporte / 2;
            END IF;
        END IF;
 
        -- Bono sede
        v_rec.bono_sede := 0;
        IF v_cod_sede = 'SMA' AND v_tipo_contrato != 'SERVICIOS' THEN
            v_rec.bono_sede := g_params.bono_clima_sma;
        END IF;
 
        -- Bruto
        v_rec.bruto := v_rec.salario_base_q + v_rec.recargos + v_rec.bonificacion
                     + v_rec.auxilio_transp + v_rec.bono_sede;
 
        -- Deducciones
        v_ded := fn_deducciones(v_rec.bruto, p_id_empleado);
        v_rec.deduccion_salud    := v_ded.deduccion_salud;
        v_rec.deduccion_pension  := v_ded.deduccion_pension;
        v_rec.fondo_solidaridad  := v_ded.fondo_solidaridad;
        v_rec.embargo            := v_ded.embargo;
        v_rec.libranzas          := v_ded.libranzas;
        v_rec.aporte_voluntario  := v_ded.aporte_voluntario;
        v_rec.total_deducciones  := v_ded.total;
        v_rec.neto               := v_rec.bruto - v_rec.total_deducciones;
 
        -- Caso especial: neto negativo
        IF v_rec.neto < 0 THEN
            v_rec.total_deducciones := v_rec.total_deducciones - v_rec.embargo;
            v_rec.embargo := 0;
            v_rec.neto    := v_rec.bruto - v_rec.total_deducciones;
            IF v_rec.neto < 0 THEN
                v_rec.total_deducciones := v_rec.total_deducciones - v_rec.libranzas;
                v_rec.libranzas := 0;
                v_rec.neto      := v_rec.bruto - v_rec.total_deducciones;
            END IF;
        END IF;
 
        RETURN v_rec;
    END calcular_liquidacion;
 

    -- sp_liquidar_quincena: un solo empleado (sobrecarga 1)

    PROCEDURE sp_liquidar_quincena(
        p_id_empleado NUMBER,
        p_id_quincena VARCHAR2
    ) IS
        v_estado    EMPLEADOS.estado%TYPE;
        v_liq_count NUMBER(5);
        v_rec       t_concepto_liq;
    BEGIN
        -- Validaciones (igual que Punto 3)
        BEGIN
            SELECT estado INTO v_estado
            FROM   EMPLEADOS WHERE id_empleado = p_id_empleado;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Empleado no encontrado: ' || p_id_empleado);
        END;
 
        IF v_estado != 'ACTIVO' THEN
            RAISE_APPLICATION_ERROR(-20002, 'Empleado no activo: estado = ' || v_estado);
        END IF;
 
        SELECT COUNT(*) INTO v_liq_count
        FROM   LIQUIDACION
        WHERE  id_empleado = p_id_empleado AND id_quincena = p_id_quincena;
 
        IF v_liq_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Liquidación ya existe para empleado ' || p_id_empleado ||
                ' quincena ' || p_id_quincena);
        END IF;
 
        -- Calcular
        v_rec := calcular_liquidacion(p_id_empleado, p_id_quincena);
 
        -- Insertar en LIQUIDACION
        INSERT INTO LIQUIDACION (
            id_liquidacion, id_empleado, id_quincena,
            salario_base_q, recargos, bonificacion, auxilio_transp, bono_sede,
            bruto, deduccion_salud, deduccion_pension, fondo_solidaridad,
            embargo, libranzas, aporte_voluntario, total_deducciones, neto
        ) VALUES (
            SEQ_LIQUIDACION.NEXTVAL, v_rec.id_empleado, v_rec.id_quincena,
            v_rec.salario_base_q, v_rec.recargos, v_rec.bonificacion,
            v_rec.auxilio_transp, v_rec.bono_sede, v_rec.bruto,
            v_rec.deduccion_salud, v_rec.deduccion_pension, v_rec.fondo_solidaridad,
            v_rec.embargo, v_rec.libranzas, v_rec.aporte_voluntario,
            v_rec.total_deducciones, v_rec.neto
        );
 
        -- Auditoría
        sp_log_nomina(
            p_operacion    => 'LIQ_INDIVIDUAL',
            p_detalle      => 'Empleado ' || p_id_empleado || ' quincena ' || p_id_quincena,
            p_empleados_ok => 1,
            p_monto_total  => v_rec.neto
        );
 
        COMMIT;
 
    EXCEPTION
        WHEN OTHERS THEN
            sp_log_nomina(
                p_operacion       => 'LIQ_INDIVIDUAL_ERROR',
                p_detalle         => 'Error emp ' || p_id_empleado || ': ' || SQLERRM,
                p_empleados_error => 1
            );
            ROLLBACK;
            RAISE;
    END sp_liquidar_quincena;
 


    -- Punto 6
---------------------------------------------------------------------------
    PROCEDURE sp_liquidar_quincena(
        p_id_quincena VARCHAR2
    ) IS
        -- Punto 6 - colección de IDs
        TYPE t_ids IS TABLE OF EMPLEADOS.id_empleado%TYPE;
        v_ids        t_ids;
        v_lista_liq  t_lista_interna;  -- INDEX BY: permite asignación directa en el loop
        v_rec        t_concepto_liq;
 
        v_ok_count    NUMBER := 0;
        v_err_count   NUMBER := 0;
        v_monto_total NUMBER := 0;
        v_idx         NUMBER;
 
        -- Excepción para SAVE EXCEPTIONS
        ex_bulk_errors EXCEPTION;
        PRAGMA EXCEPTION_INIT(ex_bulk_errors, -24381);
    BEGIN
        -- BULK COLLECT de empleados activos sin liquidación existente
        SELECT id_empleado
        BULK COLLECT INTO v_ids
        FROM   EMPLEADOS
        WHERE  estado = 'ACTIVO'
        AND    id_empleado NOT IN (
            SELECT id_empleado FROM LIQUIDACION WHERE id_quincena = p_id_quincena
        );
 
        IF v_ids.COUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No hay empleados pendientes de liquidar para ' || p_id_quincena);
            RETURN;
        END IF;
 
        -- Calcular cada liquidación y llenar la colección
        FOR i IN 1 .. v_ids.COUNT LOOP
            BEGIN
                v_rec := calcular_liquidacion(v_ids(i), p_id_quincena);
                v_lista_liq(i) := v_rec;
            EXCEPTION
                WHEN OTHERS THEN
                    -- Usar registro en blanco si falla el cálculo (constructor de objeto)
                    v_lista_liq(i) := t_concepto_liq(
                        v_ids(i), p_id_quincena,
                        0, 0, 0, 0, 0,   -- salario_base_q, recargos, bonificacion, auxilio_transp, bono_sede
                        0,               -- bruto
                        0, 0, 0,         -- deduccion_salud, deduccion_pension, fondo_solidaridad
                        0, 0, 0,         -- embargo, libranzas, aporte_voluntario
                        0, 0             -- total_deducciones, neto
                    );
            END;
        END LOOP;
 
        -- FORALL con SAVE EXCEPTIONS para inserción masiva
        BEGIN
            FORALL i IN 1 .. v_lista_liq.COUNT SAVE EXCEPTIONS
                INSERT INTO LIQUIDACION (
                    id_liquidacion, id_empleado, id_quincena,
                    salario_base_q, recargos, bonificacion, auxilio_transp, bono_sede,
                    bruto, deduccion_salud, deduccion_pension, fondo_solidaridad,
                    embargo, libranzas, aporte_voluntario, total_deducciones, neto
                ) VALUES (
                    SEQ_LIQUIDACION.NEXTVAL,
                    v_lista_liq(i).id_empleado,
                    v_lista_liq(i).id_quincena,
                    v_lista_liq(i).salario_base_q,
                    v_lista_liq(i).recargos,
                    v_lista_liq(i).bonificacion,
                    v_lista_liq(i).auxilio_transp,
                    v_lista_liq(i).bono_sede,
                    v_lista_liq(i).bruto,
                    v_lista_liq(i).deduccion_salud,
                    v_lista_liq(i).deduccion_pension,
                    v_lista_liq(i).fondo_solidaridad,
                    v_lista_liq(i).embargo,
                    v_lista_liq(i).libranzas,
                    v_lista_liq(i).aporte_voluntario,
                    v_lista_liq(i).total_deducciones,
                    v_lista_liq(i).neto
                );
            v_ok_count := SQL%ROWCOUNT;
        EXCEPTION
            WHEN ex_bulk_errors THEN
                v_err_count := SQL%BULK_EXCEPTIONS.COUNT;
                v_ok_count  := v_lista_liq.COUNT - v_err_count;
                FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                    v_idx := SQL%BULK_EXCEPTIONS(j).ERROR_INDEX;
                    sp_log_nomina(
                        p_operacion       => 'BULK_ERROR',
                        p_detalle         => 'Error emp ' || v_lista_liq(v_idx).id_empleado
                                            || ': ' || SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE),
                        p_empleados_error => 1
                    );
                END LOOP;
        END;
 
        -- Calcular monto total de los insertados correctamente
        SELECT NVL(SUM(neto), 0) INTO v_monto_total
        FROM   LIQUIDACION
        WHERE  id_quincena = p_id_quincena;
 
        DBMS_OUTPUT.PUT_LINE('Procesados OK: ' || v_ok_count || ' | Errores: ' || v_err_count);
 
        -- Auditoría del lote
        sp_log_nomina(
            p_operacion       => 'LIQ_MASIVA',
            p_detalle         => 'Liquidación masiva quincena ' || p_id_quincena,
            p_empleados_ok    => v_ok_count,
            p_empleados_error => v_err_count,
            p_monto_total     => v_monto_total
        );
 
        COMMIT;
 
    EXCEPTION
        WHEN OTHERS THEN
            sp_log_nomina(
                p_operacion       => 'LIQ_MASIVA_ERROR',
                p_detalle         => 'Error general: ' || SQLERRM,
                p_empleados_error => 1
            );
            ROLLBACK;
            RAISE;
    END sp_liquidar_quincena;
 
    -- -------------------------------------------------------
    -- fn_total_nomina_sede
    -- -------------------------------------------------------
    FUNCTION fn_total_nomina_sede(
        p_cod_sede    VARCHAR2,
        p_id_quincena VARCHAR2
    ) RETURN NUMBER IS
        v_total NUMBER(15,2);
    BEGIN
        SELECT NVL(SUM(l.neto), 0)
        INTO   v_total
        FROM   LIQUIDACION l
        JOIN   EMPLEADOS   e ON e.id_empleado = l.id_empleado
        WHERE  e.cod_sede   = p_cod_sede
        AND    l.id_quincena = p_id_quincena;
        RETURN v_total;
    END fn_total_nomina_sede;
 

    -- PUNTO 7 — Pipelined Function + SQL Dinámico
------------------------------------------------------------------------
    FUNCTION fn_reporte_nomina(
        p_cod_sede      VARCHAR2 DEFAULT NULL,
        p_tipo_contrato VARCHAR2 DEFAULT NULL
    ) RETURN t_lista_liq PIPELINED IS
        v_sql    VARCHAR2(2000);
        v_cursor SYS_REFCURSOR;
        -- Variables locales para FETCH (no se puede hacer FETCH INTO atributos de objeto)
        v_id_empleado       NUMBER(6);
        v_id_quincena       VARCHAR2(15);
        v_salario_base_q    NUMBER(12,2);
        v_recargos          NUMBER(12,2);
        v_bonificacion      NUMBER(12,2);
        v_auxilio_transp    NUMBER(12,2);
        v_bono_sede         NUMBER(12,2);
        v_bruto             NUMBER(12,2);
        v_deduccion_salud   NUMBER(12,2);
        v_deduccion_pension NUMBER(12,2);
        v_fondo_solidaridad NUMBER(12,2);
        v_embargo           NUMBER(12,2);
        v_libranzas         NUMBER(12,2);
        v_aporte_voluntario NUMBER(12,2);
        v_total_deducciones NUMBER(12,2);
        v_neto              NUMBER(12,2);
    BEGIN
        -- Construir query dinámico base
        v_sql := 'SELECT l.id_empleado, l.id_quincena, l.salario_base_q, l.recargos, '
              || 'l.bonificacion, l.auxilio_transp, l.bono_sede, l.bruto, '
              || 'l.deduccion_salud, l.deduccion_pension, l.fondo_solidaridad, '
              || 'l.embargo, l.libranzas, l.aporte_voluntario, '
              || 'l.total_deducciones, l.neto '
              || 'FROM LIQUIDACION l '
              || 'JOIN EMPLEADOS e ON e.id_empleado = l.id_empleado '
              || 'WHERE 1=1 ';
 
        -- Filtros opcionales: se agrega siempre el bind variable para mantener
        -- el mismo número de parámetros en el OPEN ... USING
        IF p_cod_sede IS NOT NULL THEN
            v_sql := v_sql || 'AND e.cod_sede = :b_sede ';
        ELSE
            v_sql := v_sql || 'AND (:b_sede IS NULL OR 1=1) ';
        END IF;
 
        IF p_tipo_contrato IS NOT NULL THEN
            v_sql := v_sql || 'AND e.tipo_contrato = :b_tipo ';
        ELSE
            v_sql := v_sql || 'AND (:b_tipo IS NULL OR 1=1) ';
        END IF;
 
        -- Abrir cursor dinámico con bind variables siempre presentes
        OPEN v_cursor FOR v_sql
            USING p_cod_sede, p_tipo_contrato;
 
        -- Fetch en locales y construir objeto para PIPE ROW
        LOOP
            FETCH v_cursor INTO
                v_id_empleado, v_id_quincena,
                v_salario_base_q, v_recargos, v_bonificacion,
                v_auxilio_transp, v_bono_sede, v_bruto,
                v_deduccion_salud, v_deduccion_pension, v_fondo_solidaridad,
                v_embargo, v_libranzas, v_aporte_voluntario,
                v_total_deducciones, v_neto;
            EXIT WHEN v_cursor%NOTFOUND;
            -- Construir objeto con constructor y emitirlo
            PIPE ROW(t_concepto_liq(
                v_id_empleado, v_id_quincena,
                v_salario_base_q, v_recargos, v_bonificacion,
                v_auxilio_transp, v_bono_sede, v_bruto,
                v_deduccion_salud, v_deduccion_pension, v_fondo_solidaridad,
                v_embargo, v_libranzas, v_aporte_voluntario,
                v_total_deducciones, v_neto
            ));
        END LOOP;
        CLOSE v_cursor;
        RETURN;
    END fn_reporte_nomina;
 
    -- -------------------------------------------------------
    -- Bloque de inicialización del package
    -- Carga parámetros al caché la primera vez que se usa el package en la sesión
    -- -------------------------------------------------------
BEGIN
    SELECT valor_numerico INTO g_params.smlmv             FROM PARAMETROS WHERE cod_parametro = 'SMLMV';
    SELECT valor_numerico INTO g_params.aux_transporte     FROM PARAMETROS WHERE cod_parametro = 'AUX_TRANSPORTE';
    SELECT valor_numerico INTO g_params.pct_salud          FROM PARAMETROS WHERE cod_parametro = 'PCT_SALUD';
    SELECT valor_numerico INTO g_params.pct_pension        FROM PARAMETROS WHERE cod_parametro = 'PCT_PENSION';
    SELECT valor_numerico INTO g_params.pct_fondo          FROM PARAMETROS WHERE cod_parametro = 'PCT_FONDO_SOLIDARIDAD';
    SELECT valor_numerico INTO g_params.umbral_fondo_smlmv FROM PARAMETROS WHERE cod_parametro = 'UMBRAL_FONDO_SMLMV';
    SELECT valor_numerico INTO g_params.rec_nocturno       FROM PARAMETROS WHERE cod_parametro = 'RECARGO_NOCTURNO';
    SELECT valor_numerico INTO g_params.rec_dominical      FROM PARAMETROS WHERE cod_parametro = 'RECARGO_DOMINICAL';
    SELECT valor_numerico INTO g_params.rec_noct_dom       FROM PARAMETROS WHERE cod_parametro = 'RECARGO_NOCT_DOM';
    SELECT valor_numerico INTO g_params.ret_servicios      FROM PARAMETROS WHERE cod_parametro = 'RET_SERVICIOS';
    SELECT valor_numerico INTO g_params.bono_clima_sma     FROM PARAMETROS WHERE cod_parametro = 'BONO_CLIMA_SMA';
    SELECT valor_numerico INTO g_params.aporte_vol_bog     FROM PARAMETROS WHERE cod_parametro = 'APORTE_VOL_BOG';
 
    -- Inicializar constante pública
    gc_smlmv := g_params.smlmv;
 
END PKG_NOMINA;
/

-- Validaciones (Punto 4)
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name IN ('PKG_NOMINA','T_CONCEPTO_LIQ_OBJ','T_LISTA_LIQ_OBJ')
ORDER BY object_type;


SELECT PKG_NOMINA.gc_smlmv AS smlmv_vigente FROM DUAL;

BEGIN
    PKG_NOMINA.sp_liquidar_quincena(1001, '2026-Q1-ENE');
END;
/
SELECT * FROM LIQUIDACION WHERE id_empleado = 1001;


BEGIN
    PKG_NOMINA.sp_liquidar_quincena(1019, '2026-Q1-ENE');
END;
/
SELECT id_empleado, salario_base_q, recargos, bonificacion, bruto, neto
FROM   LIQUIDACION WHERE id_empleado = 1019;


-- Validaciones (Punto 6)
BEGIN
    PKG_NOMINA.sp_liquidar_quincena('2026-Q1-ENE');
END;
/

BEGIN
    PKG_NOMINA.sp_liquidar_quincena('2026-Q1-ENE');
END;
/

-- Validaciones (Punto 7)

SELECT * FROM TABLE(PKG_NOMINA.fn_reporte_nomina(NULL, NULL));

SELECT id_empleado, id_quincena, bruto, neto
FROM   TABLE(PKG_NOMINA.fn_reporte_nomina('BOG', NULL));

-- Validaciones (Punto 8)
SELECT id_log,
       TO_CHAR(fecha_hora, 'DD/MM/YYYY HH24:MI:SS') AS fecha_hora,
       operacion, usuario, empleados_ok,
       empleados_error,
       TO_CHAR(monto_total, 'FM99,999,999.00') AS monto
FROM   LOG_NOMINA
ORDER  BY id_log;


-- ============================================================
-- PUNTO 5 — Compound Trigger sobre LIQUIDACION
-- ============================================================
CREATE OR REPLACE TRIGGER trg_liquidacion_compound
FOR INSERT ON LIQUIDACION
COMPOUND TRIGGER
 
    -- Variable de sección para rastrear si hubo ajuste de neto negativo
    v_neto_negativo BOOLEAN := FALSE;
 
    -- -------------------------------------------------------
    -- BEFORE EACH ROW: validar y ajustar antes de insertar
    -- -------------------------------------------------------
    BEFORE EACH ROW IS
    BEGIN
        -- Validar salario base no negativo
        IF :NEW.salario_base_q < 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Salario base no puede ser negativo');
        END IF;
 
        -- Manejar neto negativo: Regla 8 caso especial
        IF :NEW.neto < 0 THEN
            v_neto_negativo := TRUE;
            -- Paso 1: ajustar embargo a 0
            :NEW.total_deducciones := :NEW.total_deducciones - :NEW.embargo;
            :NEW.embargo           := 0;
            :NEW.neto              := :NEW.bruto - :NEW.total_deducciones;
 
            -- Paso 2: si sigue negativo, ajustar libranzas a 0
            IF :NEW.neto < 0 THEN
                :NEW.total_deducciones := :NEW.total_deducciones - :NEW.libranzas;
                :NEW.libranzas         := 0;
                :NEW.neto              := :NEW.bruto - :NEW.total_deducciones;
            END IF;
        END IF;
    END BEFORE EACH ROW;
 
    -- -------------------------------------------------------
    -- AFTER EACH ROW: actualizar libranzas y log de alerta
    -- -------------------------------------------------------
    AFTER EACH ROW IS
    BEGIN
        -- Si hubo ajuste por neto negativo, loguear alerta
        IF v_neto_negativo THEN
            INSERT INTO LOG_NOMINA (
                id_log, fecha_hora, operacion, usuario, detalle
            ) VALUES (
                SEQ_LOG.NEXTVAL, SYSTIMESTAMP, 'ALERTA_NETO_NEGATIVO', USER,
                'Empleado ' || :NEW.id_empleado || ' quincena ' || :NEW.id_quincena
                || ': embargo y/o libranzas ajustados a $0. Neto final: ' || :NEW.neto
            );
            v_neto_negativo := FALSE;
        END IF;
 
        -- Actualizar saldo_pendiente de libranzas activas del empleado
        -- Restar el monto descontado esta quincena
        IF :NEW.libranzas > 0 THEN
            -- Distribuir el descuento entre libranzas activas proporcionalmente (simplificado: restar de la primera)
            UPDATE LIBRANZAS
            SET    saldo_pendiente = saldo_pendiente - :NEW.libranzas
            WHERE  id_empleado     = :NEW.id_empleado
            AND    estado          = 'ACTIVA'
            AND    ROWNUM          = 1;
 
            -- Marcar como PAGADA si saldo llega a 0 o menos
            UPDATE LIBRANZAS
            SET    estado = 'PAGADA'
            WHERE  id_empleado     = :NEW.id_empleado
            AND    estado          = 'ACTIVA'
            AND    saldo_pendiente <= 0;
        END IF;
    END AFTER EACH ROW;
 
    -- -------------------------------------------------------
    -- AFTER STATEMENT: log del lote procesado
    -- -------------------------------------------------------
    AFTER STATEMENT IS
    BEGIN
        INSERT INTO LOG_NOMINA (
            id_log, fecha_hora, operacion, usuario, detalle
        ) VALUES (
            SEQ_LOG.NEXTVAL, SYSTIMESTAMP, 'INSERT_LIQUIDACION', USER,
            'Lote procesado a las ' || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF3')
        );
    END AFTER STATEMENT;
 
END trg_liquidacion_compound;
/
 
 
-- BLOQUE DE PRUEBA FINAL
-- Ejecuta la liquidación masiva y muestra resultados
--------------------------------------------------------------------
SET SERVEROUTPUT ON SIZE UNLIMITED;
 
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== INICIANDO LIQUIDACIÓN MASIVA 2026-Q1-ENE ===');
    PKG_NOMINA.sp_liquidar_quincena('2026-Q1-ENE');
    DBMS_OUTPUT.PUT_LINE('=== LIQUIDACIÓN COMPLETADA ===');
END;
/
 
-- Mostrar resultados
SELECT
    l.id_liquidacion,
    e.nombre,
    e.tipo_contrato,
    e.cod_sede,
    l.salario_base_q,
    l.recargos,
    l.bonificacion,
    l.auxilio_transp,
    l.bono_sede,
    l.bruto,
    l.deduccion_salud,
    l.deduccion_pension,
    l.fondo_solidaridad,
    l.embargo,
    l.libranzas,
    l.aporte_voluntario,
    l.total_deducciones,
    l.neto
FROM LIQUIDACION l
JOIN EMPLEADOS e ON e.id_empleado = l.id_empleado
ORDER BY l.id_liquidacion;
 
-- Verificar log de auditoría
SELECT * FROM LOG_NOMINA ORDER BY id_log;