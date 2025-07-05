-- 修改balance字段类型为FLOAT8以兼容Rust的f64类型
ALTER TABLE users ALTER COLUMN balance TYPE FLOAT8;
