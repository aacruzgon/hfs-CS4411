CONSISTENCY LOCAL_QUORUM;
CREATE TABLE IF NOT EXISTS spike.nulltest (pk text PRIMARY KEY, a text, b text);
INSERT INTO spike.nulltest (pk,a,b) VALUES ('explicit_null','x',null);
INSERT INTO spike.nulltest (pk,a) VALUES ('omitted','x');
