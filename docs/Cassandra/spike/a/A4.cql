CONSISTENCY LOCAL_QUORUM;
CREATE TABLE spike.tok (tenant_id text, system text, code text, id text, PRIMARY KEY ((tenant_id, system, code), id));
INSERT INTO spike.tok (tenant_id,system,code,id) VALUES ('t1','','8480-6','obs1');
INSERT INTO spike.tok (tenant_id,system,code,id) VALUES ('t1','http://loinc.org','8480-6','obs2');
SELECT * FROM spike.tok WHERE tenant_id='t1' AND system='' AND code='8480-6';
SELECT * FROM spike.tok;
-- composite key with empty code too
INSERT INTO spike.tok (tenant_id,system,code,id) VALUES ('t1','','','obs3');
SELECT * FROM spike.tok WHERE tenant_id='t1' AND system='' AND code='';
-- single-column text partition key = ''
CREATE TABLE spike.single (k text PRIMARY KEY, v text);
INSERT INTO spike.single (k,v) VALUES ('', 'x');
SELECT * FROM spike.single WHERE k='';
INSERT INTO spike.single (k,v) VALUES ('a', 'x');
-- single-column partition key with empty clustering part for comparison
CREATE TABLE spike.single2 (k text, c text, v text, PRIMARY KEY (k, c));
INSERT INTO spike.single2 (k,c,v) VALUES ('', 'c', 'x');
INSERT INTO spike.single2 (k,c,v) VALUES ('k', '', 'x');
SELECT * FROM spike.single2 WHERE k='k' AND c='';
