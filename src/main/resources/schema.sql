-- =============================================================
-- Git Manager - Schema do Banco de Dados PostgreSQL
-- =============================================================

-- Tabela de Usuários
CREATE TABLE IF NOT EXISTS users (
    id          BIGSERIAL PRIMARY KEY,
    username    VARCHAR(100) NOT NULL UNIQUE,
    email       VARCHAR(255) NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,  -- Hash BCrypt
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Tabela de Projetos Git
CREATE TABLE IF NOT EXISTS git_projects (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name         VARCHAR(255) NOT NULL,          -- Nome/alias definido pelo usuário
    path         VARCHAR(1024) NOT NULL,         -- Caminho absoluto no filesystem
    remote_url   VARCHAR(1024),                  -- URL do repositório remoto (pode ser nulo)
    notes        TEXT,                           -- Observações do usuário
    created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, path)                        -- Mesmo usuário não pode ter o mesmo path duplicado
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_git_projects_user_id ON git_projects(user_id);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers de updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_git_projects_updated_at ON git_projects;
CREATE TRIGGER update_git_projects_updated_at
    BEFORE UPDATE ON git_projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
