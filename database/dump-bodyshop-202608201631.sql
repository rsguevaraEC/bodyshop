--
-- PostgreSQL database dump
--

-- Dumped from database version 16.14
-- Dumped by pg_dump version 17.4

-- Started on 2026-08-20 16:31:38

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 4423 (class 1262 OID 24770)
-- Name: bodyshop; Type: DATABASE; Schema: -; Owner: adminpgsql
--

CREATE DATABASE bodyshop WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.utf8';


ALTER DATABASE bodyshop OWNER TO adminpgsql;

\connect bodyshop

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 6 (class 2615 OID 24771)
-- Name: bodyshop; Type: SCHEMA; Schema: -; Owner: adminpgsql
--

CREATE SCHEMA bodyshop;


ALTER SCHEMA bodyshop OWNER TO adminpgsql;

--
-- TOC entry 268 (class 1255 OID 24772)
-- Name: fn_actualiza_inventario(); Type: FUNCTION; Schema: bodyshop; Owner: adminpgsql
--

CREATE FUNCTION bodyshop.fn_actualiza_inventario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    cant NUMERIC(10,2);
    costo_prom NUMERIC(10,2);
    nuevo_costo_promedio NUMERIC(10,2);
BEGIN
    --------------------------------------------------------------------
    -- ENTRADA: actualiza inventario y costo promedio
    --------------------------------------------------------------------
    IF NEW.tipo_movimiento = 'ENTRADA' THEN
        
        SELECT cantidad, costo_promedio
        INTO cant, costo_prom
        FROM bodyshop.material_inventario
        WHERE material_pk = NEW.material_pk
          AND taller_pk = NEW.taller_pk;

        -- Si no existe inventario previo, inicializa
        IF NOT FOUND THEN
            INSERT INTO bodyshop.material_inventario (material_pk, taller_pk, cantidad, costo_promedio)
            VALUES (NEW.material_pk, NEW.taller_pk, NEW.cantidad, NEW.costo_unitario);
        ELSE
            nuevo_costo_promedio :=
                (cant * costo_prom + NEW.cantidad * NEW.costo_unitario)
                / (cant + NEW.cantidad);

            UPDATE bodyshop.material_inventario
            SET cantidad = cant + NEW.cantidad,
                costo_promedio = nuevo_costo_promedio
            WHERE material_pk = NEW.material_pk
              AND taller_pk = NEW.taller_pk;
        END IF;

    --------------------------------------------------------------------
    -- SALIDA: descuenta inventario y usa costo promedio vigente
    --------------------------------------------------------------------
    ELSIF NEW.tipo_movimiento = 'SALIDA' THEN
        
        SELECT cantidad, costo_promedio
        INTO cant, costo_prom
        FROM bodyshop.material_inventario
        WHERE material_pk = NEW.material_pk
          AND taller_pk = NEW.taller_pk;

        -- Si no existe inventario, error
        IF NOT FOUND THEN
            RAISE EXCEPTION 'No existe inventario para material % en taller %', NEW.material_pk, NEW.taller_pk;
        END IF;

        -- Evitar inventario negativo
        IF cant < NEW.cantidad THEN
            RAISE EXCEPTION 'Inventario insuficiente: disponible %, solicitado %', cant, NEW.cantidad;
        END IF;

        -- Asignar costo promedio vigente
        NEW.costo_unitario := costo_prom;
        NEW.costo_total := costo_prom * NEW.cantidad;

        -- Actualizar inventario
        UPDATE bodyshop.material_inventario
        SET cantidad = cant - NEW.cantidad
        WHERE material_pk = NEW.material_pk
          AND taller_pk = NEW.taller_pk;

    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION bodyshop.fn_actualiza_inventario() OWNER TO adminpgsql;

--
-- TOC entry 269 (class 1255 OID 24773)
-- Name: fn_ot_materiales_calculo(); Type: FUNCTION; Schema: bodyshop; Owner: adminpgsql
--

CREATE FUNCTION bodyshop.fn_ot_materiales_calculo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.costo_total := NEW.cantidad * NEW.costo_unitario;
    RETURN NEW;
END;
$$;


ALTER FUNCTION bodyshop.fn_ot_materiales_calculo() OWNER TO adminpgsql;

--
-- TOC entry 272 (class 1255 OID 24774)
-- Name: fn_ot_set_vin_y_anio(); Type: FUNCTION; Schema: bodyshop; Owner: adminpgsql
--

CREATE FUNCTION bodyshop.fn_ot_set_vin_y_anio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    vin10 CHAR(1);
    anio INT;
BEGIN
    -- Si hay VIN y tiene al menos 10 caracteres
    IF NEW.orden_vin IS NOT NULL AND length(NEW.orden_vin) >= 10 THEN
        
        -- VIN7: primeros 7 dígitos
        NEW.orden_vin7 := substring(NEW.orden_vin FROM 1 FOR 7);
        
        -- VIN10: décimo dígito
        vin10 := substring(NEW.orden_vin FROM 10 FOR 1);
        NEW.orden_vin10 := vin10;

        -- Buscar año modelo en la tabla vin_anio_modelo
        SELECT anio_modelo INTO anio
        FROM bodyshop.vin_anio_modelo
        WHERE vin_codigo = vin10;

        NEW.orden_anio_modelo := anio;
    ELSE
        NEW.orden_vin7 := NULL;
        NEW.orden_vin10 := NULL;
        NEW.orden_anio_modelo := NULL;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION bodyshop.fn_ot_set_vin_y_anio() OWNER TO adminpgsql;

--
-- TOC entry 273 (class 1255 OID 24775)
-- Name: fn_set_vin7(); Type: FUNCTION; Schema: bodyshop; Owner: adminpgsql
--

CREATE FUNCTION bodyshop.fn_set_vin7() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Si el VIN no es nulo y tiene al menos 7 caracteres
    IF NEW.vehiculo_vin IS NOT NULL AND length(NEW.vehiculo_vin) >= 7 THEN
        NEW.vehiculo_vin7 := substring(NEW.vehiculo_vin FROM 1 FOR 7);
    ELSE
        NEW.vehiculo_vin7 := NULL;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION bodyshop.fn_set_vin7() OWNER TO adminpgsql;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 216 (class 1259 OID 24776)
-- Name: area_taller_empresa; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.area_taller_empresa (
    area_pk integer NOT NULL,
    empresa_pk character varying(13) NOT NULL,
    area_nombre character varying(80) NOT NULL,
    area_estado boolean DEFAULT true,
    area_tipo character varying(3) NOT NULL,
    CONSTRAINT area_taller_empresa_area_tipo_check CHECK (((area_tipo)::text = ANY (ARRAY[('MOD'::character varying)::text, ('MOI'::character varying)::text])))
);


ALTER TABLE bodyshop.area_taller_empresa OWNER TO adminpgsql;

--
-- TOC entry 217 (class 1259 OID 24781)
-- Name: area_taller_empresa_area_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.area_taller_empresa_area_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.area_taller_empresa_area_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4424 (class 0 OID 0)
-- Dependencies: 217
-- Name: area_taller_empresa_area_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.area_taller_empresa_area_pk_seq OWNED BY bodyshop.area_taller_empresa.area_pk;


--
-- TOC entry 218 (class 1259 OID 24782)
-- Name: cargo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.cargo (
    cargo_pk integer NOT NULL,
    cargo_nombre character varying(50) NOT NULL,
    cargo_estado boolean DEFAULT true
);


ALTER TABLE bodyshop.cargo OWNER TO adminpgsql;

--
-- TOC entry 219 (class 1259 OID 24786)
-- Name: cargo_cargo_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.cargo_cargo_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.cargo_cargo_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4425 (class 0 OID 0)
-- Dependencies: 219
-- Name: cargo_cargo_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.cargo_cargo_pk_seq OWNED BY bodyshop.cargo.cargo_pk;


--
-- TOC entry 220 (class 1259 OID 24787)
-- Name: cliente; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.cliente (
    cliente_pk character varying(13) NOT NULL,
    cliente_nombre character varying(120) NOT NULL,
    cliente_direccion character varying(200),
    cliente_telefono_fijo character varying(20),
    cliente_telefono_movil character varying(20),
    cliente_email character varying(120),
    cliente_tipo character varying(20) NOT NULL,
    cliente_estado boolean DEFAULT true,
    CONSTRAINT chk_cliente_pk_len CHECK (((length((cliente_pk)::text) = 10) OR (length((cliente_pk)::text) = 13))),
    CONSTRAINT chk_cliente_tipo CHECK (((cliente_tipo)::text = ANY (ARRAY[('FINAL'::character varying)::text, ('EMPRESA'::character varying)::text, ('FLOTA'::character varying)::text, ('ASEGURADORA'::character varying)::text])))
);


ALTER TABLE bodyshop.cliente OWNER TO adminpgsql;

--
-- TOC entry 221 (class 1259 OID 24795)
-- Name: cuenta_contable_empresa; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.cuenta_contable_empresa (
    cuenta_pk integer NOT NULL,
    empresa_pk character varying(13) NOT NULL,
    cuenta_codigo character varying(20) NOT NULL,
    cuenta_nombre character varying(120) NOT NULL,
    cuenta_estado boolean DEFAULT true
);


ALTER TABLE bodyshop.cuenta_contable_empresa OWNER TO adminpgsql;

--
-- TOC entry 222 (class 1259 OID 24799)
-- Name: cuenta_contable_empresa_cuenta_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.cuenta_contable_empresa_cuenta_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.cuenta_contable_empresa_cuenta_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4426 (class 0 OID 0)
-- Dependencies: 222
-- Name: cuenta_contable_empresa_cuenta_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.cuenta_contable_empresa_cuenta_pk_seq OWNED BY bodyshop.cuenta_contable_empresa.cuenta_pk;


--
-- TOC entry 223 (class 1259 OID 24800)
-- Name: empresa; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.empresa (
    empresa_pk character varying(13) NOT NULL,
    empresa_nombre character varying(80) NOT NULL,
    empresa_direccion character varying(80),
    empresa_telefono character varying(20),
    empresa_representante_legal character varying(120),
    empresa_estado boolean DEFAULT true,
    empresa_logo_url character varying(500),
    empresa_emails character varying(400),
    empresa_pais character varying(50)
);


ALTER TABLE bodyshop.empresa OWNER TO adminpgsql;

--
-- TOC entry 4427 (class 0 OID 0)
-- Dependencies: 223
-- Name: COLUMN empresa.empresa_representante_legal; Type: COMMENT; Schema: bodyshop; Owner: adminpgsql
--

COMMENT ON COLUMN bodyshop.empresa.empresa_representante_legal IS 'Nombre del representante legal';


--
-- TOC entry 224 (class 1259 OID 24804)
-- Name: gf_catalogo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.gf_catalogo (
    gf_pk integer NOT NULL,
    empresa_pk character varying(13) NOT NULL,
    gf_nombre character varying(120) NOT NULL,
    gf_descripcion text,
    gf_estado boolean DEFAULT true,
    tipo_gasto character varying(3) NOT NULL,
    cuenta_codigo character varying(20),
    cuenta_nombre character varying(120),
    CONSTRAINT gf_catalogo_tipo_gasto_check CHECK (((tipo_gasto)::text = 'GF'::text))
);


ALTER TABLE bodyshop.gf_catalogo OWNER TO adminpgsql;

--
-- TOC entry 225 (class 1259 OID 24811)
-- Name: gf_catalogo_gf_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.gf_catalogo_gf_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.gf_catalogo_gf_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4428 (class 0 OID 0)
-- Dependencies: 225
-- Name: gf_catalogo_gf_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.gf_catalogo_gf_pk_seq OWNED BY bodyshop.gf_catalogo.gf_pk;


--
-- TOC entry 226 (class 1259 OID 24812)
-- Name: gf_taller_mensual; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.gf_taller_mensual (
    registro_pk integer NOT NULL,
    taller_pk integer NOT NULL,
    gf_pk integer NOT NULL,
    anio integer NOT NULL,
    mes integer NOT NULL,
    monto_mes numeric(12,2) NOT NULL,
    CONSTRAINT gf_taller_mensual_mes_check CHECK (((mes >= 1) AND (mes <= 12)))
);


ALTER TABLE bodyshop.gf_taller_mensual OWNER TO adminpgsql;

--
-- TOC entry 227 (class 1259 OID 24816)
-- Name: gf_taller_mensual_registro_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.gf_taller_mensual_registro_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.gf_taller_mensual_registro_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4429 (class 0 OID 0)
-- Dependencies: 227
-- Name: gf_taller_mensual_registro_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.gf_taller_mensual_registro_pk_seq OWNED BY bodyshop.gf_taller_mensual.registro_pk;


--
-- TOC entry 228 (class 1259 OID 24817)
-- Name: gga_catalogo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.gga_catalogo (
    gga_pk integer NOT NULL,
    empresa_pk character varying(13) NOT NULL,
    gga_nombre character varying(120) NOT NULL,
    gga_descripcion text,
    gga_estado boolean DEFAULT true,
    tipo_gasto character varying(3) NOT NULL,
    cuenta_codigo character varying(20),
    cuenta_nombre character varying(120),
    CONSTRAINT gga_catalogo_tipo_gasto_check CHECK (((tipo_gasto)::text = 'GGA'::text))
);


ALTER TABLE bodyshop.gga_catalogo OWNER TO adminpgsql;

--
-- TOC entry 229 (class 1259 OID 24824)
-- Name: gga_catalogo_gga_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.gga_catalogo_gga_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.gga_catalogo_gga_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4430 (class 0 OID 0)
-- Dependencies: 229
-- Name: gga_catalogo_gga_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.gga_catalogo_gga_pk_seq OWNED BY bodyshop.gga_catalogo.gga_pk;


--
-- TOC entry 230 (class 1259 OID 24825)
-- Name: gga_taller_mensual; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.gga_taller_mensual (
    registro_pk integer NOT NULL,
    taller_pk integer NOT NULL,
    gga_pk integer NOT NULL,
    anio integer NOT NULL,
    mes integer NOT NULL,
    monto_mes numeric(12,2) NOT NULL,
    CONSTRAINT gga_taller_mensual_mes_check CHECK (((mes >= 1) AND (mes <= 12)))
);


ALTER TABLE bodyshop.gga_taller_mensual OWNER TO adminpgsql;

--
-- TOC entry 231 (class 1259 OID 24829)
-- Name: gga_taller_mensual_registro_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.gga_taller_mensual_registro_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.gga_taller_mensual_registro_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4431 (class 0 OID 0)
-- Dependencies: 231
-- Name: gga_taller_mensual_registro_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.gga_taller_mensual_registro_pk_seq OWNED BY bodyshop.gga_taller_mensual.registro_pk;


--
-- TOC entry 232 (class 1259 OID 24830)
-- Name: ggf_catalogo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.ggf_catalogo (
    ggf_pk integer NOT NULL,
    empresa_pk character varying(13) NOT NULL,
    ggf_nombre character varying(120) NOT NULL,
    ggf_descripcion text,
    ggf_estado boolean DEFAULT true,
    tipo_gasto character varying(3) NOT NULL,
    cuenta_codigo character varying(20),
    cuenta_nombre character varying(120),
    CONSTRAINT ggf_catalogo_tipo_gasto_check CHECK (((tipo_gasto)::text = ANY (ARRAY[('GGF'::character varying)::text, ('GI'::character varying)::text])))
);


ALTER TABLE bodyshop.ggf_catalogo OWNER TO adminpgsql;

--
-- TOC entry 233 (class 1259 OID 24837)
-- Name: ggf_catalogo_ggf_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.ggf_catalogo_ggf_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.ggf_catalogo_ggf_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4432 (class 0 OID 0)
-- Dependencies: 233
-- Name: ggf_catalogo_ggf_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.ggf_catalogo_ggf_pk_seq OWNED BY bodyshop.ggf_catalogo.ggf_pk;


--
-- TOC entry 234 (class 1259 OID 24838)
-- Name: ggf_taller_mensual; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.ggf_taller_mensual (
    registro_pk integer NOT NULL,
    taller_pk integer NOT NULL,
    ggf_pk integer NOT NULL,
    anio integer NOT NULL,
    mes integer NOT NULL,
    monto_mes numeric(12,2) NOT NULL,
    CONSTRAINT ggf_taller_mensual_mes_check CHECK (((mes >= 1) AND (mes <= 12)))
);


ALTER TABLE bodyshop.ggf_taller_mensual OWNER TO adminpgsql;

--
-- TOC entry 235 (class 1259 OID 24842)
-- Name: ggf_taller_mensual_registro_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.ggf_taller_mensual_registro_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.ggf_taller_mensual_registro_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4433 (class 0 OID 0)
-- Dependencies: 235
-- Name: ggf_taller_mensual_registro_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.ggf_taller_mensual_registro_pk_seq OWNED BY bodyshop.ggf_taller_mensual.registro_pk;


--
-- TOC entry 236 (class 1259 OID 24843)
-- Name: gv_catalogo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.gv_catalogo (
    gv_pk integer NOT NULL,
    empresa_pk character varying(13) NOT NULL,
    gv_nombre character varying(120) NOT NULL,
    gv_descripcion text,
    gv_estado boolean DEFAULT true,
    tipo_gasto character varying(3) NOT NULL,
    cuenta_codigo character varying(20),
    cuenta_nombre character varying(120),
    CONSTRAINT gv_catalogo_tipo_gasto_check CHECK (((tipo_gasto)::text = 'GV'::text))
);


ALTER TABLE bodyshop.gv_catalogo OWNER TO adminpgsql;

--
-- TOC entry 237 (class 1259 OID 24850)
-- Name: gv_catalogo_gv_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.gv_catalogo_gv_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.gv_catalogo_gv_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4434 (class 0 OID 0)
-- Dependencies: 237
-- Name: gv_catalogo_gv_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.gv_catalogo_gv_pk_seq OWNED BY bodyshop.gv_catalogo.gv_pk;


--
-- TOC entry 238 (class 1259 OID 24851)
-- Name: gv_taller_mensual; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.gv_taller_mensual (
    registro_pk integer NOT NULL,
    taller_pk integer NOT NULL,
    gv_pk integer NOT NULL,
    anio integer NOT NULL,
    mes integer NOT NULL,
    monto_mes numeric(12,2) NOT NULL,
    CONSTRAINT gv_taller_mensual_mes_check CHECK (((mes >= 1) AND (mes <= 12)))
);


ALTER TABLE bodyshop.gv_taller_mensual OWNER TO adminpgsql;

--
-- TOC entry 239 (class 1259 OID 24855)
-- Name: gv_taller_mensual_registro_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.gv_taller_mensual_registro_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.gv_taller_mensual_registro_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4435 (class 0 OID 0)
-- Dependencies: 239
-- Name: gv_taller_mensual_registro_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.gv_taller_mensual_registro_pk_seq OWNED BY bodyshop.gv_taller_mensual.registro_pk;


--
-- TOC entry 240 (class 1259 OID 24856)
-- Name: maestro_materiales; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.maestro_materiales (
    material_pk integer NOT NULL,
    material_codigo character varying(20) NOT NULL,
    material_descripcion character varying(120) NOT NULL,
    material_marca character varying(50),
    material_unidad_medida character varying(10),
    material_tipo character varying(50),
    material_estado boolean DEFAULT true,
    material_costo_unitario numeric(10,2),
    material_stock_minimo integer DEFAULT 0,
    material_stock_actual integer DEFAULT 0,
    empresa_pk character varying(13),
    taller_pk integer,
    proveedor_pk character varying(13),
    material_codigo_pintura character varying(6),
    cuenta_codigo character varying(20),
    cuenta_nombre character varying(120)
);


ALTER TABLE bodyshop.maestro_materiales OWNER TO adminpgsql;

--
-- TOC entry 4436 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN maestro_materiales.material_codigo_pintura; Type: COMMENT; Schema: bodyshop; Owner: adminpgsql
--

COMMENT ON COLUMN bodyshop.maestro_materiales.material_codigo_pintura IS 'Código de pintura del fabricante asociado al material';


--
-- TOC entry 241 (class 1259 OID 24862)
-- Name: maestro_materiales_material_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.maestro_materiales_material_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.maestro_materiales_material_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4437 (class 0 OID 0)
-- Dependencies: 241
-- Name: maestro_materiales_material_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.maestro_materiales_material_pk_seq OWNED BY bodyshop.maestro_materiales.material_pk;


--
-- TOC entry 242 (class 1259 OID 24863)
-- Name: marca; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.marca (
    marca_pk integer NOT NULL,
    marca_nombre character varying(50) NOT NULL,
    marca_estado boolean DEFAULT true
);


ALTER TABLE bodyshop.marca OWNER TO adminpgsql;

--
-- TOC entry 243 (class 1259 OID 24867)
-- Name: marca_marca_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.marca_marca_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.marca_marca_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4438 (class 0 OID 0)
-- Dependencies: 243
-- Name: marca_marca_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.marca_marca_pk_seq OWNED BY bodyshop.marca.marca_pk;


--
-- TOC entry 244 (class 1259 OID 24868)
-- Name: material_inventario; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.material_inventario (
    inventario_pk integer NOT NULL,
    material_pk integer NOT NULL,
    taller_pk integer NOT NULL,
    cantidad numeric(10,2) DEFAULT 0 NOT NULL,
    costo_promedio numeric(10,2) DEFAULT 0 NOT NULL
);


ALTER TABLE bodyshop.material_inventario OWNER TO adminpgsql;

--
-- TOC entry 245 (class 1259 OID 24873)
-- Name: material_inventario_inventario_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.material_inventario_inventario_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.material_inventario_inventario_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4439 (class 0 OID 0)
-- Dependencies: 245
-- Name: material_inventario_inventario_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.material_inventario_inventario_pk_seq OWNED BY bodyshop.material_inventario.inventario_pk;


--
-- TOC entry 246 (class 1259 OID 24874)
-- Name: material_movimientos; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.material_movimientos (
    movimiento_pk integer NOT NULL,
    material_pk integer NOT NULL,
    fecha_movimiento timestamp without time zone DEFAULT now() NOT NULL,
    tipo_movimiento character varying(10) NOT NULL,
    cantidad numeric(10,2) NOT NULL,
    costo_unitario numeric(10,2) NOT NULL,
    costo_total numeric(10,2) NOT NULL,
    orden_trabajo_pk integer,
    taller_pk integer NOT NULL,
    trabajador_pk integer NOT NULL
);


ALTER TABLE bodyshop.material_movimientos OWNER TO adminpgsql;

--
-- TOC entry 247 (class 1259 OID 24878)
-- Name: material_movimientos_movimiento_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.material_movimientos_movimiento_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.material_movimientos_movimiento_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4440 (class 0 OID 0)
-- Dependencies: 247
-- Name: material_movimientos_movimiento_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.material_movimientos_movimiento_pk_seq OWNED BY bodyshop.material_movimientos.movimiento_pk;


--
-- TOC entry 248 (class 1259 OID 24879)
-- Name: modelo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.modelo (
    modelo_pk integer NOT NULL,
    marca_pk integer NOT NULL,
    modelo_nombre character varying(50) NOT NULL,
    modelo_estado boolean DEFAULT true
);


ALTER TABLE bodyshop.modelo OWNER TO adminpgsql;

--
-- TOC entry 249 (class 1259 OID 24883)
-- Name: modelo_modelo_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.modelo_modelo_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.modelo_modelo_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4441 (class 0 OID 0)
-- Dependencies: 249
-- Name: modelo_modelo_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.modelo_modelo_pk_seq OWNED BY bodyshop.modelo.modelo_pk;


--
-- TOC entry 250 (class 1259 OID 24884)
-- Name: orden_trabajo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.orden_trabajo (
    orden_trabajo_pk integer NOT NULL,
    orden_trabajo_numero character varying(20) NOT NULL,
    vehiculo_pk integer NOT NULL,
    taller_pk integer NOT NULL,
    trabajador_pk integer NOT NULL,
    fecha_ingreso timestamp without time zone DEFAULT now() NOT NULL,
    fecha_salida timestamp without time zone,
    estado_ot character varying(20) DEFAULT 'ABIERTA'::character varying,
    observacion character varying(200),
    orden_vin character varying(17),
    orden_vin7 character varying(7),
    orden_vin10 character(1),
    orden_anio_modelo integer,
    cliente_pk character varying(13),
    orden_numero_paneles integer DEFAULT 0,
    color2 character varying(50),
    color1 character varying(50),
    costo_panel numeric(10,2)
);


ALTER TABLE bodyshop.orden_trabajo OWNER TO adminpgsql;

--
-- TOC entry 4442 (class 0 OID 0)
-- Dependencies: 250
-- Name: COLUMN orden_trabajo.orden_numero_paneles; Type: COMMENT; Schema: bodyshop; Owner: adminpgsql
--

COMMENT ON COLUMN bodyshop.orden_trabajo.orden_numero_paneles IS 'Cantidad de paneles involucrados en la orden de trabajo';


--
-- TOC entry 4443 (class 0 OID 0)
-- Dependencies: 250
-- Name: COLUMN orden_trabajo.costo_panel; Type: COMMENT; Schema: bodyshop; Owner: adminpgsql
--

COMMENT ON COLUMN bodyshop.orden_trabajo.costo_panel IS 'Costo promedio por panel: suma de costos de materiales dividido para el número de paneles';


--
-- TOC entry 251 (class 1259 OID 24890)
-- Name: orden_trabajo_orden_trabajo_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.orden_trabajo_orden_trabajo_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.orden_trabajo_orden_trabajo_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4444 (class 0 OID 0)
-- Dependencies: 251
-- Name: orden_trabajo_orden_trabajo_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.orden_trabajo_orden_trabajo_pk_seq OWNED BY bodyshop.orden_trabajo.orden_trabajo_pk;


--
-- TOC entry 252 (class 1259 OID 24891)
-- Name: ot_materiales; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.ot_materiales (
    ot_material_pk integer NOT NULL,
    orden_trabajo_pk integer NOT NULL,
    material_pk integer NOT NULL,
    cantidad numeric(10,2) NOT NULL,
    costo_unitario numeric(10,2) NOT NULL,
    costo_total numeric(10,2) NOT NULL,
    fecha_consumo timestamp without time zone DEFAULT now() NOT NULL,
    taller_pk integer NOT NULL,
    trabajador_pk integer NOT NULL
);


ALTER TABLE bodyshop.ot_materiales OWNER TO adminpgsql;

--
-- TOC entry 253 (class 1259 OID 24895)
-- Name: ot_materiales_ot_material_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.ot_materiales_ot_material_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.ot_materiales_ot_material_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4445 (class 0 OID 0)
-- Dependencies: 253
-- Name: ot_materiales_ot_material_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.ot_materiales_ot_material_pk_seq OWNED BY bodyshop.ot_materiales.ot_material_pk;


--
-- TOC entry 254 (class 1259 OID 24896)
-- Name: proveedor; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.proveedor (
    proveedor_pk character varying(13) NOT NULL,
    proveedor_nombre character varying(120) NOT NULL,
    proveedor_direccion character varying(150),
    proveedor_telefono character varying(20),
    proveedor_contacto character varying(100),
    proveedor_estado boolean DEFAULT true
);


ALTER TABLE bodyshop.proveedor OWNER TO adminpgsql;

--
-- TOC entry 255 (class 1259 OID 24900)
-- Name: taller; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.taller (
    taller_pk integer NOT NULL,
    empresa_pk character varying(13) NOT NULL,
    taller_nombre character varying(80) NOT NULL,
    taller_direccion character varying(200),
    taller_telefono character varying(20),
    taller_estado boolean DEFAULT true,
    taller_responsable character varying,
    taller_ciudad character varying(100)
);


ALTER TABLE bodyshop.taller OWNER TO adminpgsql;

--
-- TOC entry 4446 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN taller.taller_estado; Type: COMMENT; Schema: bodyshop; Owner: adminpgsql
--

COMMENT ON COLUMN bodyshop.taller.taller_estado IS 'Estado del taller (activo/inactivo)';


--
-- TOC entry 4447 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN taller.taller_responsable; Type: COMMENT; Schema: bodyshop; Owner: adminpgsql
--

COMMENT ON COLUMN bodyshop.taller.taller_responsable IS 'Jefe de taller';


--
-- TOC entry 256 (class 1259 OID 24906)
-- Name: trabajador; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.trabajador (
    trabajador_pk integer NOT NULL,
    trabajador_nombre character varying(120) NOT NULL,
    trabajador_cedula character varying(10),
    trabajador_telefono character varying(20),
    trabajador_email character varying(120),
    cargo_pk integer NOT NULL,
    taller_pk integer NOT NULL,
    trabajador_estado boolean DEFAULT true,
    area_pk integer,
    cuenta_codigo character varying(20),
    cuenta_nombre character varying(120)
);


ALTER TABLE bodyshop.trabajador OWNER TO adminpgsql;

--
-- TOC entry 257 (class 1259 OID 24910)
-- Name: trabajador_costos_mensuales; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.trabajador_costos_mensuales (
    costo_pk integer NOT NULL,
    trabajador_pk integer NOT NULL,
    anio integer NOT NULL,
    mes integer NOT NULL,
    horas_mes numeric(10,2) NOT NULL,
    sueldo_mes numeric(10,2) NOT NULL,
    comisiones_mes numeric(10,2) DEFAULT 0,
    costo_total_mes numeric(10,2) GENERATED ALWAYS AS ((sueldo_mes + comisiones_mes)) STORED,
    CONSTRAINT trabajador_costos_mensuales_mes_check CHECK (((mes >= 1) AND (mes <= 12)))
);


ALTER TABLE bodyshop.trabajador_costos_mensuales OWNER TO adminpgsql;

--
-- TOC entry 258 (class 1259 OID 24916)
-- Name: trabajador_costos_mensuales_costo_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.trabajador_costos_mensuales_costo_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.trabajador_costos_mensuales_costo_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4448 (class 0 OID 0)
-- Dependencies: 258
-- Name: trabajador_costos_mensuales_costo_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.trabajador_costos_mensuales_costo_pk_seq OWNED BY bodyshop.trabajador_costos_mensuales.costo_pk;


--
-- TOC entry 259 (class 1259 OID 24917)
-- Name: trabajador_trabajador_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.trabajador_trabajador_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.trabajador_trabajador_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4449 (class 0 OID 0)
-- Dependencies: 259
-- Name: trabajador_trabajador_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.trabajador_trabajador_pk_seq OWNED BY bodyshop.trabajador.trabajador_pk;


--
-- TOC entry 260 (class 1259 OID 24918)
-- Name: vehiculo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.vehiculo (
    vehiculo_pk integer NOT NULL,
    vehiculo_placa character varying(10),
    marca_pk integer,
    modelo_pk integer,
    version_pk integer
);


ALTER TABLE bodyshop.vehiculo OWNER TO adminpgsql;

--
-- TOC entry 261 (class 1259 OID 24921)
-- Name: vehiculo_vehiculo_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.vehiculo_vehiculo_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.vehiculo_vehiculo_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4450 (class 0 OID 0)
-- Dependencies: 261
-- Name: vehiculo_vehiculo_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.vehiculo_vehiculo_pk_seq OWNED BY bodyshop.vehiculo.vehiculo_pk;


--
-- TOC entry 262 (class 1259 OID 24922)
-- Name: version; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.version (
    version_pk integer NOT NULL,
    modelo_pk integer NOT NULL,
    version_nombre character varying(50) NOT NULL,
    version_estado boolean DEFAULT true
);


ALTER TABLE bodyshop.version OWNER TO adminpgsql;

--
-- TOC entry 263 (class 1259 OID 24926)
-- Name: version_version_pk_seq; Type: SEQUENCE; Schema: bodyshop; Owner: adminpgsql
--

CREATE SEQUENCE bodyshop.version_version_pk_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE bodyshop.version_version_pk_seq OWNER TO adminpgsql;

--
-- TOC entry 4451 (class 0 OID 0)
-- Dependencies: 263
-- Name: version_version_pk_seq; Type: SEQUENCE OWNED BY; Schema: bodyshop; Owner: adminpgsql
--

ALTER SEQUENCE bodyshop.version_version_pk_seq OWNED BY bodyshop.version.version_pk;


--
-- TOC entry 264 (class 1259 OID 24927)
-- Name: vin_anio_modelo; Type: TABLE; Schema: bodyshop; Owner: adminpgsql
--

CREATE TABLE bodyshop.vin_anio_modelo (
    vin_codigo character(1) NOT NULL,
    anio_modelo integer NOT NULL,
    vigente boolean DEFAULT true
);


ALTER TABLE bodyshop.vin_anio_modelo OWNER TO adminpgsql;

--
-- TOC entry 4066 (class 2604 OID 24931)
-- Name: area_taller_empresa area_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.area_taller_empresa ALTER COLUMN area_pk SET DEFAULT nextval('bodyshop.area_taller_empresa_area_pk_seq'::regclass);


--
-- TOC entry 4068 (class 2604 OID 24932)
-- Name: cargo cargo_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.cargo ALTER COLUMN cargo_pk SET DEFAULT nextval('bodyshop.cargo_cargo_pk_seq'::regclass);


--
-- TOC entry 4071 (class 2604 OID 24933)
-- Name: cuenta_contable_empresa cuenta_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.cuenta_contable_empresa ALTER COLUMN cuenta_pk SET DEFAULT nextval('bodyshop.cuenta_contable_empresa_cuenta_pk_seq'::regclass);


--
-- TOC entry 4074 (class 2604 OID 24934)
-- Name: gf_catalogo gf_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gf_catalogo ALTER COLUMN gf_pk SET DEFAULT nextval('bodyshop.gf_catalogo_gf_pk_seq'::regclass);


--
-- TOC entry 4076 (class 2604 OID 24935)
-- Name: gf_taller_mensual registro_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gf_taller_mensual ALTER COLUMN registro_pk SET DEFAULT nextval('bodyshop.gf_taller_mensual_registro_pk_seq'::regclass);


--
-- TOC entry 4077 (class 2604 OID 24936)
-- Name: gga_catalogo gga_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gga_catalogo ALTER COLUMN gga_pk SET DEFAULT nextval('bodyshop.gga_catalogo_gga_pk_seq'::regclass);


--
-- TOC entry 4079 (class 2604 OID 24937)
-- Name: gga_taller_mensual registro_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gga_taller_mensual ALTER COLUMN registro_pk SET DEFAULT nextval('bodyshop.gga_taller_mensual_registro_pk_seq'::regclass);


--
-- TOC entry 4080 (class 2604 OID 24938)
-- Name: ggf_catalogo ggf_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ggf_catalogo ALTER COLUMN ggf_pk SET DEFAULT nextval('bodyshop.ggf_catalogo_ggf_pk_seq'::regclass);


--
-- TOC entry 4082 (class 2604 OID 24939)
-- Name: ggf_taller_mensual registro_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ggf_taller_mensual ALTER COLUMN registro_pk SET DEFAULT nextval('bodyshop.ggf_taller_mensual_registro_pk_seq'::regclass);


--
-- TOC entry 4083 (class 2604 OID 24940)
-- Name: gv_catalogo gv_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gv_catalogo ALTER COLUMN gv_pk SET DEFAULT nextval('bodyshop.gv_catalogo_gv_pk_seq'::regclass);


--
-- TOC entry 4085 (class 2604 OID 24941)
-- Name: gv_taller_mensual registro_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gv_taller_mensual ALTER COLUMN registro_pk SET DEFAULT nextval('bodyshop.gv_taller_mensual_registro_pk_seq'::regclass);


--
-- TOC entry 4086 (class 2604 OID 24942)
-- Name: maestro_materiales material_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.maestro_materiales ALTER COLUMN material_pk SET DEFAULT nextval('bodyshop.maestro_materiales_material_pk_seq'::regclass);


--
-- TOC entry 4090 (class 2604 OID 24943)
-- Name: marca marca_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.marca ALTER COLUMN marca_pk SET DEFAULT nextval('bodyshop.marca_marca_pk_seq'::regclass);


--
-- TOC entry 4092 (class 2604 OID 24944)
-- Name: material_inventario inventario_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_inventario ALTER COLUMN inventario_pk SET DEFAULT nextval('bodyshop.material_inventario_inventario_pk_seq'::regclass);


--
-- TOC entry 4095 (class 2604 OID 24945)
-- Name: material_movimientos movimiento_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_movimientos ALTER COLUMN movimiento_pk SET DEFAULT nextval('bodyshop.material_movimientos_movimiento_pk_seq'::regclass);


--
-- TOC entry 4097 (class 2604 OID 24946)
-- Name: modelo modelo_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.modelo ALTER COLUMN modelo_pk SET DEFAULT nextval('bodyshop.modelo_modelo_pk_seq'::regclass);


--
-- TOC entry 4099 (class 2604 OID 24947)
-- Name: orden_trabajo orden_trabajo_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.orden_trabajo ALTER COLUMN orden_trabajo_pk SET DEFAULT nextval('bodyshop.orden_trabajo_orden_trabajo_pk_seq'::regclass);


--
-- TOC entry 4103 (class 2604 OID 24948)
-- Name: ot_materiales ot_material_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ot_materiales ALTER COLUMN ot_material_pk SET DEFAULT nextval('bodyshop.ot_materiales_ot_material_pk_seq'::regclass);


--
-- TOC entry 4107 (class 2604 OID 24949)
-- Name: trabajador trabajador_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.trabajador ALTER COLUMN trabajador_pk SET DEFAULT nextval('bodyshop.trabajador_trabajador_pk_seq'::regclass);


--
-- TOC entry 4109 (class 2604 OID 24950)
-- Name: trabajador_costos_mensuales costo_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.trabajador_costos_mensuales ALTER COLUMN costo_pk SET DEFAULT nextval('bodyshop.trabajador_costos_mensuales_costo_pk_seq'::regclass);


--
-- TOC entry 4112 (class 2604 OID 24951)
-- Name: vehiculo vehiculo_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.vehiculo ALTER COLUMN vehiculo_pk SET DEFAULT nextval('bodyshop.vehiculo_vehiculo_pk_seq'::regclass);


--
-- TOC entry 4113 (class 2604 OID 24952)
-- Name: version version_pk; Type: DEFAULT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.version ALTER COLUMN version_pk SET DEFAULT nextval('bodyshop.version_version_pk_seq'::regclass);


--
-- TOC entry 4369 (class 0 OID 24776)
-- Dependencies: 216
-- Data for Name: area_taller_empresa; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.area_taller_empresa (area_pk, empresa_pk, area_nombre, area_estado, area_tipo) FROM stdin;
1	EMP001	Recepción técnica	t	MOI
2	EMP001	Administración	t	MOI
3	EMP001	Bodega	t	MOI
4	EMP001	Control de calidad	t	MOI
5	EMP001	Atención al cliente	t	MOI
6	EMP001	Facturación	t	MOI
7	EMP001	Supervisión	t	MOI
8	EMP001	Logística interna	t	MOI
9	EMP001	Pintura	t	MOD
10	EMP001	Enderezado	t	MOD
11	EMP001	Mecánica	t	MOD
12	EMP001	Electricidad	t	MOD
13	EMP001	Detallado	t	MOD
14	EMP001	Preparación	t	MOD
15	EMP001	Pulido	t	MOD
16	EMP001	Alineación y balanceo	t	MOD
17	EMP001	Diagnóstico técnico	t	MOD
\.


--
-- TOC entry 4371 (class 0 OID 24782)
-- Dependencies: 218
-- Data for Name: cargo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.cargo (cargo_pk, cargo_nombre, cargo_estado) FROM stdin;
\.


--
-- TOC entry 4373 (class 0 OID 24787)
-- Dependencies: 220
-- Data for Name: cliente; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.cliente (cliente_pk, cliente_nombre, cliente_direccion, cliente_telefono_fijo, cliente_telefono_movil, cliente_email, cliente_tipo, cliente_estado) FROM stdin;
\.


--
-- TOC entry 4374 (class 0 OID 24795)
-- Dependencies: 221
-- Data for Name: cuenta_contable_empresa; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.cuenta_contable_empresa (cuenta_pk, empresa_pk, cuenta_codigo, cuenta_nombre, cuenta_estado) FROM stdin;
\.


--
-- TOC entry 4376 (class 0 OID 24800)
-- Dependencies: 223
-- Data for Name: empresa; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.empresa (empresa_pk, empresa_nombre, empresa_direccion, empresa_telefono, empresa_representante_legal, empresa_estado, empresa_logo_url, empresa_emails, empresa_pais) FROM stdin;
1891796494001	Ecuatoriana de Comercio y Servicios Siempre Originales CIA LTDA	Av. Leonidas Plaza 0604	+593032844287	Romeo Santiago Guevara	t	\N	facturas@100preoriginales.com	Ecuador
EMP002	Empresa Modelo Bodyshop2	La Direccion de ahora	0554854545	Representate legal 1	f		mail2@yahoo.es	Colombia
EMP001	Empresa Modelo Bodyshop	La Dirección modelo 1	+593089745624	Representante Legal	t	\N	mail1@dominio.com; mail2@yahoo.com\r\n	Argentina
189000013001	Automotores de la Sierra	Av. Atahualpa y Rio Guayllabamba	+593032845672	Santiago Sevilla	t	\N	facturas@aasa.com.ec	Ecuador
\.


--
-- TOC entry 4377 (class 0 OID 24804)
-- Dependencies: 224
-- Data for Name: gf_catalogo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.gf_catalogo (gf_pk, empresa_pk, gf_nombre, gf_descripcion, gf_estado, tipo_gasto, cuenta_codigo, cuenta_nombre) FROM stdin;
\.


--
-- TOC entry 4379 (class 0 OID 24812)
-- Dependencies: 226
-- Data for Name: gf_taller_mensual; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.gf_taller_mensual (registro_pk, taller_pk, gf_pk, anio, mes, monto_mes) FROM stdin;
\.


--
-- TOC entry 4381 (class 0 OID 24817)
-- Dependencies: 228
-- Data for Name: gga_catalogo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.gga_catalogo (gga_pk, empresa_pk, gga_nombre, gga_descripcion, gga_estado, tipo_gasto, cuenta_codigo, cuenta_nombre) FROM stdin;
\.


--
-- TOC entry 4383 (class 0 OID 24825)
-- Dependencies: 230
-- Data for Name: gga_taller_mensual; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.gga_taller_mensual (registro_pk, taller_pk, gga_pk, anio, mes, monto_mes) FROM stdin;
\.


--
-- TOC entry 4385 (class 0 OID 24830)
-- Dependencies: 232
-- Data for Name: ggf_catalogo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.ggf_catalogo (ggf_pk, empresa_pk, ggf_nombre, ggf_descripcion, ggf_estado, tipo_gasto, cuenta_codigo, cuenta_nombre) FROM stdin;
\.


--
-- TOC entry 4387 (class 0 OID 24838)
-- Dependencies: 234
-- Data for Name: ggf_taller_mensual; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.ggf_taller_mensual (registro_pk, taller_pk, ggf_pk, anio, mes, monto_mes) FROM stdin;
\.


--
-- TOC entry 4389 (class 0 OID 24843)
-- Dependencies: 236
-- Data for Name: gv_catalogo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.gv_catalogo (gv_pk, empresa_pk, gv_nombre, gv_descripcion, gv_estado, tipo_gasto, cuenta_codigo, cuenta_nombre) FROM stdin;
\.


--
-- TOC entry 4391 (class 0 OID 24851)
-- Dependencies: 238
-- Data for Name: gv_taller_mensual; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.gv_taller_mensual (registro_pk, taller_pk, gv_pk, anio, mes, monto_mes) FROM stdin;
\.


--
-- TOC entry 4393 (class 0 OID 24856)
-- Dependencies: 240
-- Data for Name: maestro_materiales; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.maestro_materiales (material_pk, material_codigo, material_descripcion, material_marca, material_unidad_medida, material_tipo, material_estado, material_costo_unitario, material_stock_minimo, material_stock_actual, empresa_pk, taller_pk, proveedor_pk, material_codigo_pintura, cuenta_codigo, cuenta_nombre) FROM stdin;
\.


--
-- TOC entry 4395 (class 0 OID 24863)
-- Dependencies: 242
-- Data for Name: marca; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.marca (marca_pk, marca_nombre, marca_estado) FROM stdin;
\.


--
-- TOC entry 4397 (class 0 OID 24868)
-- Dependencies: 244
-- Data for Name: material_inventario; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.material_inventario (inventario_pk, material_pk, taller_pk, cantidad, costo_promedio) FROM stdin;
\.


--
-- TOC entry 4399 (class 0 OID 24874)
-- Dependencies: 246
-- Data for Name: material_movimientos; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.material_movimientos (movimiento_pk, material_pk, fecha_movimiento, tipo_movimiento, cantidad, costo_unitario, costo_total, orden_trabajo_pk, taller_pk, trabajador_pk) FROM stdin;
\.


--
-- TOC entry 4401 (class 0 OID 24879)
-- Dependencies: 248
-- Data for Name: modelo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.modelo (modelo_pk, marca_pk, modelo_nombre, modelo_estado) FROM stdin;
\.


--
-- TOC entry 4403 (class 0 OID 24884)
-- Dependencies: 250
-- Data for Name: orden_trabajo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.orden_trabajo (orden_trabajo_pk, orden_trabajo_numero, vehiculo_pk, taller_pk, trabajador_pk, fecha_ingreso, fecha_salida, estado_ot, observacion, orden_vin, orden_vin7, orden_vin10, orden_anio_modelo, cliente_pk, orden_numero_paneles, color2, color1, costo_panel) FROM stdin;
\.


--
-- TOC entry 4405 (class 0 OID 24891)
-- Dependencies: 252
-- Data for Name: ot_materiales; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.ot_materiales (ot_material_pk, orden_trabajo_pk, material_pk, cantidad, costo_unitario, costo_total, fecha_consumo, taller_pk, trabajador_pk) FROM stdin;
\.


--
-- TOC entry 4407 (class 0 OID 24896)
-- Dependencies: 254
-- Data for Name: proveedor; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.proveedor (proveedor_pk, proveedor_nombre, proveedor_direccion, proveedor_telefono, proveedor_contacto, proveedor_estado) FROM stdin;
\.


--
-- TOC entry 4408 (class 0 OID 24900)
-- Dependencies: 255
-- Data for Name: taller; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.taller (taller_pk, empresa_pk, taller_nombre, taller_direccion, taller_telefono, taller_estado, taller_responsable, taller_ciudad) FROM stdin;
\.


--
-- TOC entry 4409 (class 0 OID 24906)
-- Dependencies: 256
-- Data for Name: trabajador; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.trabajador (trabajador_pk, trabajador_nombre, trabajador_cedula, trabajador_telefono, trabajador_email, cargo_pk, taller_pk, trabajador_estado, area_pk, cuenta_codigo, cuenta_nombre) FROM stdin;
\.


--
-- TOC entry 4410 (class 0 OID 24910)
-- Dependencies: 257
-- Data for Name: trabajador_costos_mensuales; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.trabajador_costos_mensuales (costo_pk, trabajador_pk, anio, mes, horas_mes, sueldo_mes, comisiones_mes) FROM stdin;
\.


--
-- TOC entry 4413 (class 0 OID 24918)
-- Dependencies: 260
-- Data for Name: vehiculo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.vehiculo (vehiculo_pk, vehiculo_placa, marca_pk, modelo_pk, version_pk) FROM stdin;
\.


--
-- TOC entry 4415 (class 0 OID 24922)
-- Dependencies: 262
-- Data for Name: version; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.version (version_pk, modelo_pk, version_nombre, version_estado) FROM stdin;
\.


--
-- TOC entry 4417 (class 0 OID 24927)
-- Dependencies: 264
-- Data for Name: vin_anio_modelo; Type: TABLE DATA; Schema: bodyshop; Owner: adminpgsql
--

COPY bodyshop.vin_anio_modelo (vin_codigo, anio_modelo, vigente) FROM stdin;
A	2010	t
B	2011	t
C	2012	t
D	2013	t
E	2014	t
F	2015	t
G	2016	t
H	2017	t
J	2018	t
K	2019	t
L	2020	t
M	2021	t
N	2022	t
P	2023	t
R	2024	t
S	2025	t
T	2026	t
\.


--
-- TOC entry 4452 (class 0 OID 0)
-- Dependencies: 217
-- Name: area_taller_empresa_area_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.area_taller_empresa_area_pk_seq', 17, true);


--
-- TOC entry 4453 (class 0 OID 0)
-- Dependencies: 219
-- Name: cargo_cargo_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.cargo_cargo_pk_seq', 1, false);


--
-- TOC entry 4454 (class 0 OID 0)
-- Dependencies: 222
-- Name: cuenta_contable_empresa_cuenta_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.cuenta_contable_empresa_cuenta_pk_seq', 1, false);


--
-- TOC entry 4455 (class 0 OID 0)
-- Dependencies: 225
-- Name: gf_catalogo_gf_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.gf_catalogo_gf_pk_seq', 1, false);


--
-- TOC entry 4456 (class 0 OID 0)
-- Dependencies: 227
-- Name: gf_taller_mensual_registro_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.gf_taller_mensual_registro_pk_seq', 1, false);


--
-- TOC entry 4457 (class 0 OID 0)
-- Dependencies: 229
-- Name: gga_catalogo_gga_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.gga_catalogo_gga_pk_seq', 1, false);


--
-- TOC entry 4458 (class 0 OID 0)
-- Dependencies: 231
-- Name: gga_taller_mensual_registro_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.gga_taller_mensual_registro_pk_seq', 1, false);


--
-- TOC entry 4459 (class 0 OID 0)
-- Dependencies: 233
-- Name: ggf_catalogo_ggf_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.ggf_catalogo_ggf_pk_seq', 1, false);


--
-- TOC entry 4460 (class 0 OID 0)
-- Dependencies: 235
-- Name: ggf_taller_mensual_registro_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.ggf_taller_mensual_registro_pk_seq', 1, false);


--
-- TOC entry 4461 (class 0 OID 0)
-- Dependencies: 237
-- Name: gv_catalogo_gv_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.gv_catalogo_gv_pk_seq', 1, false);


--
-- TOC entry 4462 (class 0 OID 0)
-- Dependencies: 239
-- Name: gv_taller_mensual_registro_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.gv_taller_mensual_registro_pk_seq', 1, false);


--
-- TOC entry 4463 (class 0 OID 0)
-- Dependencies: 241
-- Name: maestro_materiales_material_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.maestro_materiales_material_pk_seq', 1, false);


--
-- TOC entry 4464 (class 0 OID 0)
-- Dependencies: 243
-- Name: marca_marca_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.marca_marca_pk_seq', 1, false);


--
-- TOC entry 4465 (class 0 OID 0)
-- Dependencies: 245
-- Name: material_inventario_inventario_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.material_inventario_inventario_pk_seq', 1, false);


--
-- TOC entry 4466 (class 0 OID 0)
-- Dependencies: 247
-- Name: material_movimientos_movimiento_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.material_movimientos_movimiento_pk_seq', 1, false);


--
-- TOC entry 4467 (class 0 OID 0)
-- Dependencies: 249
-- Name: modelo_modelo_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.modelo_modelo_pk_seq', 1, false);


--
-- TOC entry 4468 (class 0 OID 0)
-- Dependencies: 251
-- Name: orden_trabajo_orden_trabajo_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.orden_trabajo_orden_trabajo_pk_seq', 1, false);


--
-- TOC entry 4469 (class 0 OID 0)
-- Dependencies: 253
-- Name: ot_materiales_ot_material_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.ot_materiales_ot_material_pk_seq', 1, false);


--
-- TOC entry 4470 (class 0 OID 0)
-- Dependencies: 258
-- Name: trabajador_costos_mensuales_costo_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.trabajador_costos_mensuales_costo_pk_seq', 1, false);


--
-- TOC entry 4471 (class 0 OID 0)
-- Dependencies: 259
-- Name: trabajador_trabajador_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.trabajador_trabajador_pk_seq', 1, false);


--
-- TOC entry 4472 (class 0 OID 0)
-- Dependencies: 261
-- Name: vehiculo_vehiculo_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.vehiculo_vehiculo_pk_seq', 1, false);


--
-- TOC entry 4473 (class 0 OID 0)
-- Dependencies: 263
-- Name: version_version_pk_seq; Type: SEQUENCE SET; Schema: bodyshop; Owner: adminpgsql
--

SELECT pg_catalog.setval('bodyshop.version_version_pk_seq', 1, false);


--
-- TOC entry 4129 (class 2606 OID 24955)
-- Name: area_taller_empresa area_taller_empresa_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.area_taller_empresa
    ADD CONSTRAINT area_taller_empresa_pkey PRIMARY KEY (area_pk);


--
-- TOC entry 4131 (class 2606 OID 24957)
-- Name: cargo cargo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.cargo
    ADD CONSTRAINT cargo_pkey PRIMARY KEY (cargo_pk);


--
-- TOC entry 4133 (class 2606 OID 24959)
-- Name: cliente cliente_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (cliente_pk);


--
-- TOC entry 4135 (class 2606 OID 24961)
-- Name: cuenta_contable_empresa cuenta_contable_empresa_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.cuenta_contable_empresa
    ADD CONSTRAINT cuenta_contable_empresa_pkey PRIMARY KEY (cuenta_pk);


--
-- TOC entry 4137 (class 2606 OID 24963)
-- Name: empresa empresa_pk; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.empresa
    ADD CONSTRAINT empresa_pk PRIMARY KEY (empresa_pk);


--
-- TOC entry 4139 (class 2606 OID 24965)
-- Name: gf_catalogo gf_catalogo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gf_catalogo
    ADD CONSTRAINT gf_catalogo_pkey PRIMARY KEY (gf_pk);


--
-- TOC entry 4141 (class 2606 OID 24967)
-- Name: gf_taller_mensual gf_taller_mensual_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gf_taller_mensual
    ADD CONSTRAINT gf_taller_mensual_pkey PRIMARY KEY (registro_pk);


--
-- TOC entry 4143 (class 2606 OID 24969)
-- Name: gga_catalogo gga_catalogo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gga_catalogo
    ADD CONSTRAINT gga_catalogo_pkey PRIMARY KEY (gga_pk);


--
-- TOC entry 4145 (class 2606 OID 24971)
-- Name: gga_taller_mensual gga_taller_mensual_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gga_taller_mensual
    ADD CONSTRAINT gga_taller_mensual_pkey PRIMARY KEY (registro_pk);


--
-- TOC entry 4147 (class 2606 OID 24973)
-- Name: ggf_catalogo ggf_catalogo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ggf_catalogo
    ADD CONSTRAINT ggf_catalogo_pkey PRIMARY KEY (ggf_pk);


--
-- TOC entry 4149 (class 2606 OID 24975)
-- Name: ggf_taller_mensual ggf_taller_mensual_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ggf_taller_mensual
    ADD CONSTRAINT ggf_taller_mensual_pkey PRIMARY KEY (registro_pk);


--
-- TOC entry 4151 (class 2606 OID 24977)
-- Name: gv_catalogo gv_catalogo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gv_catalogo
    ADD CONSTRAINT gv_catalogo_pkey PRIMARY KEY (gv_pk);


--
-- TOC entry 4153 (class 2606 OID 24979)
-- Name: gv_taller_mensual gv_taller_mensual_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gv_taller_mensual
    ADD CONSTRAINT gv_taller_mensual_pkey PRIMARY KEY (registro_pk);


--
-- TOC entry 4155 (class 2606 OID 24981)
-- Name: maestro_materiales maestro_materiales_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.maestro_materiales
    ADD CONSTRAINT maestro_materiales_pkey PRIMARY KEY (material_pk);


--
-- TOC entry 4157 (class 2606 OID 24983)
-- Name: marca marca_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.marca
    ADD CONSTRAINT marca_pkey PRIMARY KEY (marca_pk);


--
-- TOC entry 4159 (class 2606 OID 24985)
-- Name: material_inventario material_inventario_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_inventario
    ADD CONSTRAINT material_inventario_pkey PRIMARY KEY (inventario_pk);


--
-- TOC entry 4161 (class 2606 OID 24987)
-- Name: material_movimientos material_movimientos_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_movimientos
    ADD CONSTRAINT material_movimientos_pkey PRIMARY KEY (movimiento_pk);


--
-- TOC entry 4163 (class 2606 OID 24989)
-- Name: modelo modelo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.modelo
    ADD CONSTRAINT modelo_pkey PRIMARY KEY (modelo_pk);


--
-- TOC entry 4165 (class 2606 OID 24991)
-- Name: orden_trabajo orden_trabajo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.orden_trabajo
    ADD CONSTRAINT orden_trabajo_pkey PRIMARY KEY (orden_trabajo_pk);


--
-- TOC entry 4167 (class 2606 OID 24993)
-- Name: ot_materiales ot_materiales_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ot_materiales
    ADD CONSTRAINT ot_materiales_pkey PRIMARY KEY (ot_material_pk);


--
-- TOC entry 4169 (class 2606 OID 24995)
-- Name: proveedor proveedor_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.proveedor
    ADD CONSTRAINT proveedor_pkey PRIMARY KEY (proveedor_pk);


--
-- TOC entry 4171 (class 2606 OID 24997)
-- Name: taller taller_pk; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.taller
    ADD CONSTRAINT taller_pk PRIMARY KEY (taller_pk);


--
-- TOC entry 4175 (class 2606 OID 24999)
-- Name: trabajador_costos_mensuales trabajador_costos_mensuales_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.trabajador_costos_mensuales
    ADD CONSTRAINT trabajador_costos_mensuales_pkey PRIMARY KEY (costo_pk);


--
-- TOC entry 4173 (class 2606 OID 25001)
-- Name: trabajador trabajador_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.trabajador
    ADD CONSTRAINT trabajador_pkey PRIMARY KEY (trabajador_pk);


--
-- TOC entry 4177 (class 2606 OID 25003)
-- Name: vehiculo vehiculo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.vehiculo
    ADD CONSTRAINT vehiculo_pkey PRIMARY KEY (vehiculo_pk);


--
-- TOC entry 4179 (class 2606 OID 25005)
-- Name: version version_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.version
    ADD CONSTRAINT version_pkey PRIMARY KEY (version_pk);


--
-- TOC entry 4181 (class 2606 OID 25007)
-- Name: vin_anio_modelo vin_anio_modelo_pkey; Type: CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.vin_anio_modelo
    ADD CONSTRAINT vin_anio_modelo_pkey PRIMARY KEY (vin_codigo);


--
-- TOC entry 4222 (class 2620 OID 25008)
-- Name: material_movimientos trg_actualiza_inventario; Type: TRIGGER; Schema: bodyshop; Owner: adminpgsql
--

CREATE TRIGGER trg_actualiza_inventario AFTER INSERT ON bodyshop.material_movimientos FOR EACH ROW EXECUTE FUNCTION bodyshop.fn_actualiza_inventario();


--
-- TOC entry 4224 (class 2620 OID 25009)
-- Name: ot_materiales trg_ot_materiales_calculo; Type: TRIGGER; Schema: bodyshop; Owner: adminpgsql
--

CREATE TRIGGER trg_ot_materiales_calculo BEFORE INSERT OR UPDATE ON bodyshop.ot_materiales FOR EACH ROW EXECUTE FUNCTION bodyshop.fn_ot_materiales_calculo();


--
-- TOC entry 4223 (class 2620 OID 25010)
-- Name: orden_trabajo trg_ot_set_vin_y_anio; Type: TRIGGER; Schema: bodyshop; Owner: adminpgsql
--

CREATE TRIGGER trg_ot_set_vin_y_anio BEFORE INSERT OR UPDATE ON bodyshop.orden_trabajo FOR EACH ROW EXECUTE FUNCTION bodyshop.fn_ot_set_vin_y_anio();


--
-- TOC entry 4225 (class 2620 OID 25011)
-- Name: vehiculo trg_set_vin7; Type: TRIGGER; Schema: bodyshop; Owner: adminpgsql
--

CREATE TRIGGER trg_set_vin7 BEFORE INSERT OR UPDATE ON bodyshop.vehiculo FOR EACH ROW EXECUTE FUNCTION bodyshop.fn_set_vin7();


--
-- TOC entry 4182 (class 2606 OID 25012)
-- Name: area_taller_empresa fk_area_taller_empresa; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.area_taller_empresa
    ADD CONSTRAINT fk_area_taller_empresa FOREIGN KEY (empresa_pk) REFERENCES bodyshop.empresa(empresa_pk);


--
-- TOC entry 4217 (class 2606 OID 25017)
-- Name: trabajador_costos_mensuales fk_costo_trabajador; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.trabajador_costos_mensuales
    ADD CONSTRAINT fk_costo_trabajador FOREIGN KEY (trabajador_pk) REFERENCES bodyshop.trabajador(trabajador_pk);


--
-- TOC entry 4183 (class 2606 OID 25022)
-- Name: cuenta_contable_empresa fk_cuenta_empresa; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.cuenta_contable_empresa
    ADD CONSTRAINT fk_cuenta_empresa FOREIGN KEY (empresa_pk) REFERENCES bodyshop.empresa(empresa_pk);


--
-- TOC entry 4191 (class 2606 OID 25027)
-- Name: ggf_taller_mensual fk_gasto_catalogo; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ggf_taller_mensual
    ADD CONSTRAINT fk_gasto_catalogo FOREIGN KEY (ggf_pk) REFERENCES bodyshop.ggf_catalogo(ggf_pk);


--
-- TOC entry 4192 (class 2606 OID 25032)
-- Name: ggf_taller_mensual fk_gasto_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ggf_taller_mensual
    ADD CONSTRAINT fk_gasto_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4185 (class 2606 OID 25037)
-- Name: gf_taller_mensual fk_gf_catalogo; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gf_taller_mensual
    ADD CONSTRAINT fk_gf_catalogo FOREIGN KEY (gf_pk) REFERENCES bodyshop.gf_catalogo(gf_pk);


--
-- TOC entry 4184 (class 2606 OID 25042)
-- Name: gf_catalogo fk_gf_empresa; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gf_catalogo
    ADD CONSTRAINT fk_gf_empresa FOREIGN KEY (empresa_pk) REFERENCES bodyshop.empresa(empresa_pk);


--
-- TOC entry 4186 (class 2606 OID 25047)
-- Name: gf_taller_mensual fk_gf_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gf_taller_mensual
    ADD CONSTRAINT fk_gf_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4188 (class 2606 OID 25052)
-- Name: gga_taller_mensual fk_gga_catalogo; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gga_taller_mensual
    ADD CONSTRAINT fk_gga_catalogo FOREIGN KEY (gga_pk) REFERENCES bodyshop.gga_catalogo(gga_pk);


--
-- TOC entry 4187 (class 2606 OID 25057)
-- Name: gga_catalogo fk_gga_empresa; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gga_catalogo
    ADD CONSTRAINT fk_gga_empresa FOREIGN KEY (empresa_pk) REFERENCES bodyshop.empresa(empresa_pk);


--
-- TOC entry 4189 (class 2606 OID 25062)
-- Name: gga_taller_mensual fk_gga_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gga_taller_mensual
    ADD CONSTRAINT fk_gga_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4190 (class 2606 OID 25067)
-- Name: ggf_catalogo fk_ggf_empresa; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ggf_catalogo
    ADD CONSTRAINT fk_ggf_empresa FOREIGN KEY (empresa_pk) REFERENCES bodyshop.empresa(empresa_pk);


--
-- TOC entry 4194 (class 2606 OID 25072)
-- Name: gv_taller_mensual fk_gv_catalogo; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gv_taller_mensual
    ADD CONSTRAINT fk_gv_catalogo FOREIGN KEY (gv_pk) REFERENCES bodyshop.gv_catalogo(gv_pk);


--
-- TOC entry 4193 (class 2606 OID 25077)
-- Name: gv_catalogo fk_gv_empresa; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gv_catalogo
    ADD CONSTRAINT fk_gv_empresa FOREIGN KEY (empresa_pk) REFERENCES bodyshop.empresa(empresa_pk);


--
-- TOC entry 4195 (class 2606 OID 25082)
-- Name: gv_taller_mensual fk_gv_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.gv_taller_mensual
    ADD CONSTRAINT fk_gv_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4196 (class 2606 OID 25087)
-- Name: maestro_materiales fk_material_empresa; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.maestro_materiales
    ADD CONSTRAINT fk_material_empresa FOREIGN KEY (empresa_pk) REFERENCES bodyshop.empresa(empresa_pk);


--
-- TOC entry 4197 (class 2606 OID 25092)
-- Name: maestro_materiales fk_material_proveedor; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.maestro_materiales
    ADD CONSTRAINT fk_material_proveedor FOREIGN KEY (proveedor_pk) REFERENCES bodyshop.proveedor(proveedor_pk);


--
-- TOC entry 4198 (class 2606 OID 25097)
-- Name: material_inventario fk_mi_material; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_inventario
    ADD CONSTRAINT fk_mi_material FOREIGN KEY (material_pk) REFERENCES bodyshop.maestro_materiales(material_pk);


--
-- TOC entry 4199 (class 2606 OID 25102)
-- Name: material_inventario fk_mi_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_inventario
    ADD CONSTRAINT fk_mi_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4200 (class 2606 OID 25107)
-- Name: material_movimientos fk_mm_material; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_movimientos
    ADD CONSTRAINT fk_mm_material FOREIGN KEY (material_pk) REFERENCES bodyshop.maestro_materiales(material_pk);


--
-- TOC entry 4201 (class 2606 OID 25112)
-- Name: material_movimientos fk_mm_ot; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_movimientos
    ADD CONSTRAINT fk_mm_ot FOREIGN KEY (orden_trabajo_pk) REFERENCES bodyshop.orden_trabajo(orden_trabajo_pk);


--
-- TOC entry 4202 (class 2606 OID 25117)
-- Name: material_movimientos fk_mm_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_movimientos
    ADD CONSTRAINT fk_mm_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4203 (class 2606 OID 25122)
-- Name: material_movimientos fk_mm_trabajador; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.material_movimientos
    ADD CONSTRAINT fk_mm_trabajador FOREIGN KEY (trabajador_pk) REFERENCES bodyshop.trabajador(trabajador_pk);


--
-- TOC entry 4204 (class 2606 OID 25127)
-- Name: modelo fk_modelo_marca; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.modelo
    ADD CONSTRAINT fk_modelo_marca FOREIGN KEY (marca_pk) REFERENCES bodyshop.marca(marca_pk);


--
-- TOC entry 4205 (class 2606 OID 25132)
-- Name: orden_trabajo fk_ot_cliente; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.orden_trabajo
    ADD CONSTRAINT fk_ot_cliente FOREIGN KEY (cliente_pk) REFERENCES bodyshop.cliente(cliente_pk);


--
-- TOC entry 4209 (class 2606 OID 25137)
-- Name: ot_materiales fk_ot_materiales_material; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ot_materiales
    ADD CONSTRAINT fk_ot_materiales_material FOREIGN KEY (material_pk) REFERENCES bodyshop.maestro_materiales(material_pk);


--
-- TOC entry 4210 (class 2606 OID 25142)
-- Name: ot_materiales fk_ot_materiales_ot; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ot_materiales
    ADD CONSTRAINT fk_ot_materiales_ot FOREIGN KEY (orden_trabajo_pk) REFERENCES bodyshop.orden_trabajo(orden_trabajo_pk);


--
-- TOC entry 4211 (class 2606 OID 25147)
-- Name: ot_materiales fk_ot_materiales_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ot_materiales
    ADD CONSTRAINT fk_ot_materiales_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4212 (class 2606 OID 25152)
-- Name: ot_materiales fk_ot_materiales_trabajador; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.ot_materiales
    ADD CONSTRAINT fk_ot_materiales_trabajador FOREIGN KEY (trabajador_pk) REFERENCES bodyshop.trabajador(trabajador_pk);


--
-- TOC entry 4206 (class 2606 OID 25157)
-- Name: orden_trabajo fk_ot_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.orden_trabajo
    ADD CONSTRAINT fk_ot_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4207 (class 2606 OID 25162)
-- Name: orden_trabajo fk_ot_trabajador; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.orden_trabajo
    ADD CONSTRAINT fk_ot_trabajador FOREIGN KEY (trabajador_pk) REFERENCES bodyshop.trabajador(trabajador_pk);


--
-- TOC entry 4208 (class 2606 OID 25167)
-- Name: orden_trabajo fk_ot_vehiculo; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.orden_trabajo
    ADD CONSTRAINT fk_ot_vehiculo FOREIGN KEY (vehiculo_pk) REFERENCES bodyshop.vehiculo(vehiculo_pk);


--
-- TOC entry 4214 (class 2606 OID 25172)
-- Name: trabajador fk_trabajador_area_taller_empresa; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.trabajador
    ADD CONSTRAINT fk_trabajador_area_taller_empresa FOREIGN KEY (area_pk) REFERENCES bodyshop.area_taller_empresa(area_pk);


--
-- TOC entry 4215 (class 2606 OID 25177)
-- Name: trabajador fk_trabajador_cargo; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.trabajador
    ADD CONSTRAINT fk_trabajador_cargo FOREIGN KEY (cargo_pk) REFERENCES bodyshop.cargo(cargo_pk);


--
-- TOC entry 4216 (class 2606 OID 25182)
-- Name: trabajador fk_trabajador_taller; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.trabajador
    ADD CONSTRAINT fk_trabajador_taller FOREIGN KEY (taller_pk) REFERENCES bodyshop.taller(taller_pk);


--
-- TOC entry 4218 (class 2606 OID 25187)
-- Name: vehiculo fk_vehiculo_marca; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.vehiculo
    ADD CONSTRAINT fk_vehiculo_marca FOREIGN KEY (marca_pk) REFERENCES bodyshop.marca(marca_pk);


--
-- TOC entry 4219 (class 2606 OID 25192)
-- Name: vehiculo fk_vehiculo_modelo; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.vehiculo
    ADD CONSTRAINT fk_vehiculo_modelo FOREIGN KEY (modelo_pk) REFERENCES bodyshop.modelo(modelo_pk);


--
-- TOC entry 4220 (class 2606 OID 25197)
-- Name: vehiculo fk_vehiculo_version; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.vehiculo
    ADD CONSTRAINT fk_vehiculo_version FOREIGN KEY (version_pk) REFERENCES bodyshop.version(version_pk);


--
-- TOC entry 4221 (class 2606 OID 25202)
-- Name: version fk_version_modelo; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.version
    ADD CONSTRAINT fk_version_modelo FOREIGN KEY (modelo_pk) REFERENCES bodyshop.modelo(modelo_pk);


--
-- TOC entry 4213 (class 2606 OID 25207)
-- Name: taller taller_empresa_fk; Type: FK CONSTRAINT; Schema: bodyshop; Owner: adminpgsql
--

ALTER TABLE ONLY bodyshop.taller
    ADD CONSTRAINT taller_empresa_fk FOREIGN KEY (empresa_pk) REFERENCES bodyshop.empresa(empresa_pk) ON UPDATE CASCADE ON DELETE RESTRICT;


-- Completed on 2026-08-20 16:32:06

--
-- PostgreSQL database dump complete
--

