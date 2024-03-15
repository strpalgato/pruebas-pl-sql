SET SERVEROUTPUT ON;

DECLARE
    v_uf NUMBER := :v_uf;
BEGIN
    dbms_output.put_line('Inicio');
EXCEPTION
  WHEN OTHERS THEN
    -- Almacenar los datos del error en la tabla ERRORES_PROCESO
    v_error_id := SQLCODE;
    v_mensaje_error_oracle := SQLERRM;
    v_mensaje_error_usr := 'Error al procesar el empleado con RUN: ' || v_run_empleado;
    INSERT INTO ERRORES_PROCESO (ERROR_ID, MENSAJE_ERROR_ORACLE, MENSAJE_ERROR_USR)
    VALUES (v_error_id, v_mensaje_error_oracle, v_mensaje_error_usr);

    -- Realizar un rollback en caso de error
    ROLLBACK;

    -- Imprimir el mensaje de error
    DBMS_OUTPUT.PUT_LINE('Error: ' || v_mensaje_error_oracle);
END;
/


SELECT  EXTRACT(MONTH FROM SYSDATE) AS MES_PROCESO, 
        EXTRACT(YEAR FROM SYSDATE) AS ANNO_PROCESO,
        e.RUN ||'-'|| e.DVRUN AS RUN,
        e.NOMBRE ||' '|| e.APPATERNO ||' '|| e.APMATERNO AS NOMBRE_EMPLEADO,
        a.nombre_afp,
        p.nombre_prev_salud,
        CASE WHEN e.COD_AFP = 1 THEN ROUND(e.SUELDO_BASE * (0.1 + 11.44 / 100), 2)
             WHEN e.COD_AFP = 2 THEN ROUND(e.SUELDO_BASE * (0.15 + 11.48 / 100), 2)
             WHEN e.COD_AFP = 3 THEN ROUND(e.SUELDO_BASE * (0.15 + 11.27 / 100), 2)
             WHEN e.COD_AFP = 4 THEN ROUND(e.SUELDO_BASE * (0.15 + 10.77 / 100), 2)
             WHEN e.COD_AFP = 5 THEN ROUND(e.SUELDO_BASE * (0.15 + 10.41 / 100), 2)
             ELSE 0
        END AS DESCUENTO_AFP,
        CASE WHEN e.COD_PREV_SALUD = 1 THEN ROUND(e.UF_PLAN_SALUD, 2)
             ELSE e.SUELDO_BASE * 0.07
        END AS DESCUENTO_SALUD,
        CASE WHEN e.AFILIADO_SINDICATO = 1 THEN 16000
             ELSE 16000 * 0.75
        END AS DESCUENTO_SINDICATO,
        e.SUELDO_BASE + e.EXTENSION_BENEFICIOS - 
        CASE WHEN e.COD_AFP = 1 THEN ROUND(e.SUELDO_BASE * (0.1 + 11.44 / 100), 2)
             WHEN e.COD_AFP = 2 THEN ROUND(e.SUELDO_BASE * (0.15 + 11.48 / 100), 2)
             WHEN e.COD_AFP = 3 THEN ROUND(e.SUELDO_BASE * (0.15 + 11.27 / 100), 2)
             WHEN e.COD_AFP = 4 THEN ROUND(e.SUELDO_BASE * (0.15 + 10.77 / 100), 2)
             WHEN e.COD_AFP = 5 THEN ROUND(e.SUELDO_BASE * (0.15 + 10.41 / 100), 2)
             ELSE 0
        END -
        CASE WHEN e.COD_PREV_SALUD = 1 THEN ROUND(e.UF_PLAN_SALUD, 2)
             ELSE e.SUELDO_BASE * 0.07
        END -
        CASE WHEN e.AFILIADO_SINDICATO = 1 THEN 16000
             ELSE 16000 * 0.75
        END AS MONTO_A_PAGO
FROM empleado_abb e
JOIN afp a ON e.cod_afp = a.cod_afp
JOIN prev_salud p ON e.cod_prev_salud = p.cod_prev_salud;


SET SERVEROUTPUT ON;

DECLARE
  -- Variable para almacenar la UF del día
  v_uf_del_dia NUMBER := TO_NUMBER('&v_uf_del_dia'); -- Solicitar la UF del día al usuario
  v_mes_proceso NUMBER := 5;
  v_anno_proceso NUMBER := 2023;
  v_run_empleado VARCHAR2(10);
  v_nombre_empleado VARCHAR2(100);
  v_nombre_afp VARCHAR2(100);
  v_nombre_prev_salud VARCHAR2(100);
  v_descuento_afp NUMBER;
  v_descuento_salud NUMBER;
  v_descuento_sindicato NUMBER;
  v_monto_a_pago NUMBER;
  v_error_id NUMBER;
  v_mensaje_error_oracle VARCHAR2(4000);
  v_mensaje_error_usr VARCHAR2(4000);
  
  CURSOR proceso IS
    SELECT e.ID_EMPLEADO, e.RUN, e.APPATERNO, e.APMATERNO, e.NOMBRE, e.SUELDO_BASE, e.COD_AFP, e.COD_PREV_SALUD,
           a.NOMBRE_AFP, p.NOMBRE_PREV_SALUD, a.PORC, e.AFILIADO_SINDICATO, e.EXTENSION_BENEFICIOS
    FROM EMPLEADO_ABB e
    INNER JOIN AFP a ON e.COD_AFP = a.COD_AFP
    INNER JOIN PREV_SALUD p ON e.COD_PREV_SALUD = p.COD_PREV_SALUD;

BEGIN
EXECUTE IMMEDIATE 'TRUNCATE TABLE PROCESO_PAGO_REMUNERACIONES';
EXECUTE IMMEDIATE 'TRUNCATE TABLE ERRORES_PROCESO';
FOR empleado IN proceso LOOP
    -- Asignar los datos del empleado a las variables correspondientes
    v_run_empleado := empleado.RUN;
    v_nombre_empleado := empleado.APPATERNO || ' ' || empleado.APMATERNO || ', ' || empleado.NOMBRE;
    v_nombre_afp := empleado.NOMBRE_AFP;
    v_nombre_prev_salud := empleado.NOMBRE_PREV_SALUD;

    -- Calcular descuentos y montos a pagar
    v_descuento_afp := empleado.SUELDO_BASE * (0.10 + empleado.PORC / 100);
    v_descuento_salud := CASE WHEN empleado.COD_PREV_SALUD = 'FON' THEN empleado.SUELDO_BASE * 0.07
                              WHEN empleado.COD_PREV_SALUD = 'ISA' THEN empleado.EXTENSION_BENEFICIOS * v_uf_del_dia
                              ELSE 0
                         END;
    v_descuento_sindicato := CASE WHEN empleado.AFILIADO_SINDICATO = 'SI' THEN 16000
                                  ELSE 16000 * 0.75
                             END;
    v_monto_a_pago := empleado.SUELDO_BASE + empleado.EXTENSION_BENEFICIOS + v_descuento_sindicato - v_descuento_afp - v_descuento_salud;

    -- Insertar los datos en la tabla PROCESO_PAGO_REMUNERACIONES
    INSERT INTO PROCESO_PAGO_REMUNERACIONES (MES_PROCESO, ANNO_PROCESO, RUN_EMPLEADO, NOMBRE_EMPLEADO,
                                             NOMBRE_AFP, NOMBRE_PREV_SALUD, DESCUENTO_AFP, DESCUENTO_SALUD,
                                             DESCUENTO_SINDICATO, MONTO_A_PAGO)
    VALUES (v_mes_proceso, v_anno_proceso, v_run_empleado, v_nombre_empleado, v_nombre_afp, v_nombre_prev_salud,
            v_descuento_afp, v_descuento_salud, v_descuento_sindicato, v_monto_a_pago);

  END LOOP;

  -- Confirmar los cambios en la transacción
  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    -- Almacenar los datos del error en la tabla ERRORES_PROCESO
    v_error_id := SQLCODE;
    v_mensaje_error_oracle := SQLERRM;
    v_mensaje_error_usr := 'Error al procesar el empleado con RUN: ' || v_run_empleado;
    INSERT INTO ERRORES_PROCESO (ERROR_ID, MENSAJE_ERROR_ORACLE, MENSAJE_ERROR_USR)
    VALUES (v_error_id, v_mensaje_error_oracle, v_mensaje_error_usr);

    -- Realizar un rollback en caso de error
    ROLLBACK;

    -- Imprimir el mensaje de error
    DBMS_OUTPUT.PUT_LINE('Error: ' || v_mensaje_error_oracle);

END;
/