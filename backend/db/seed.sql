-- math_fun 演示账号（仅在数据库首次初始化时执行）
-- 密码均为 123456，盐为 math_fun_salt，哈希算法 sha256(salt + password)
-- 生产环境请删除本文件或修改密码。

USE math_fun;

INSERT INTO users (username, password_hash, salt, nickname, role, grade, parent_id)
VALUES
  ('parent', 'd62fb08ae7fe54ba9999e3fe18946036b9caa86a918b80de0f49cb32a455a682',
   'math_fun_salt', '家长', 'parent', NULL, NULL),
  ('xiaoming', 'd62fb08ae7fe54ba9999e3fe18946036b9caa86a918b80de0f49cb32a455a682',
   'math_fun_salt', '小明', 'child', 2,
   (SELECT id FROM users WHERE username = 'parent'));
