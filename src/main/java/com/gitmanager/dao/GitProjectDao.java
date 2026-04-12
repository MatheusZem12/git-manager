package com.gitmanager.dao;

import com.gitmanager.model.GitProject;
import com.gitmanager.util.DatabaseConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class GitProjectDao {

    private static final Logger log = LoggerFactory.getLogger(GitProjectDao.class);

    public List<GitProject> findAllByUserId(Long userId) {
        String sql = "SELECT id, user_id, name, path, remote_url, notes, created_at, updated_at " +
                     "FROM git_projects WHERE user_id = ? ORDER BY name";
        List<GitProject> projects = new ArrayList<>();
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    projects.add(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            log.error("Erro ao listar projetos do usuário {}", userId, e);
        }
        return projects;
    }

    public Optional<GitProject> findById(Long id) {
        String sql = "SELECT id, user_id, name, path, remote_url, notes, created_at, updated_at " +
                     "FROM git_projects WHERE id = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRow(rs));
                }
            }
        } catch (SQLException e) {
            log.error("Erro ao buscar projeto por id {}", id, e);
        }
        return Optional.empty();
    }

    public Optional<GitProject> save(GitProject project) {
        String sql = "INSERT INTO git_projects (user_id, name, path, remote_url, notes) " +
                     "VALUES (?, ?, ?, ?, ?) RETURNING id, created_at, updated_at";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, project.getUserId());
            ps.setString(2, project.getName());
            ps.setString(3, project.getPath());
            ps.setString(4, project.getRemoteUrl());
            ps.setString(5, project.getNotes());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    project.setId(rs.getLong("id"));
                    project.setCreatedAt(rs.getTimestamp("created_at").toLocalDateTime());
                    project.setUpdatedAt(rs.getTimestamp("updated_at").toLocalDateTime());
                    log.info("Projeto salvo: {}", project.getName());
                    return Optional.of(project);
                }
            }
        } catch (SQLException e) {
            log.error("Erro ao salvar projeto: {}", project.getName(), e);
        }
        return Optional.empty();
    }

    public boolean update(GitProject project) {
        String sql = "UPDATE git_projects SET name = ?, path = ?, remote_url = ?, notes = ? WHERE id = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, project.getName());
            ps.setString(2, project.getPath());
            ps.setString(3, project.getRemoteUrl());
            ps.setString(4, project.getNotes());
            ps.setLong(5, project.getId());
            int rows = ps.executeUpdate();
            return rows > 0;
        } catch (SQLException e) {
            log.error("Erro ao atualizar projeto {}", project.getId(), e);
        }
        return false;
    }

    public boolean delete(Long id) {
        String sql = "DELETE FROM git_projects WHERE id = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, id);
            return ps.executeUpdate() > 0;
        } catch (SQLException e) {
            log.error("Erro ao deletar projeto {}", id, e);
        }
        return false;
    }

    public boolean existsByUserIdAndPath(Long userId, String path) {
        String sql = "SELECT COUNT(1) FROM git_projects WHERE user_id = ? AND path = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, userId);
            ps.setString(2, path);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getLong(1) > 0;
            }
        } catch (SQLException e) {
            log.error("Erro ao checar existência de projeto por path", e);
        }
        return false;
    }

    private GitProject mapRow(ResultSet rs) throws SQLException {
        GitProject p = new GitProject();
        p.setId(rs.getLong("id"));
        p.setUserId(rs.getLong("user_id"));
        p.setName(rs.getString("name"));
        p.setPath(rs.getString("path"));
        p.setRemoteUrl(rs.getString("remote_url"));
        p.setNotes(rs.getString("notes"));
        p.setCreatedAt(rs.getTimestamp("created_at").toLocalDateTime());
        p.setUpdatedAt(rs.getTimestamp("updated_at").toLocalDateTime());
        return p;
    }
}
