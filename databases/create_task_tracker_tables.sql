-- ==========================================
-- EMPLOYEE TASK TRACKING SYSTEM - DATABASE
-- Oracle APEX 24.2.11 Compatible
-- Simplified 4-Table Design
-- ==========================================

-- Table 1: EMPLOYEES
-- Stores all employee information
CREATE TABLE employees (
    employee_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE NOT NULL,
    phone VARCHAR2(20),
    department VARCHAR2(50) NOT NULL,
    job_title VARCHAR2(100),
    hire_date DATE DEFAULT SYSDATE,
    manager_id NUMBER,
    is_active VARCHAR2(1) DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
    created_date DATE DEFAULT SYSDATE,
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) 
        REFERENCES employees(employee_id)
);

-- Table 2: PROJECTS
-- Stores project information
CREATE TABLE projects (
    project_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_name VARCHAR2(150) NOT NULL,
    project_code VARCHAR2(20) UNIQUE NOT NULL,
    description VARCHAR2(500),
    start_date DATE NOT NULL,
    end_date DATE,
    budget NUMBER(12,2),
    status VARCHAR2(20) DEFAULT 'Planning' 
        CHECK (status IN ('Planning', 'Active', 'On Hold', 'Completed', 'Cancelled')),
    priority VARCHAR2(10) DEFAULT 'Medium' 
        CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    completion_percentage NUMBER(3) DEFAULT 0 
        CHECK (completion_percentage BETWEEN 0 AND 100),
    project_manager_id NUMBER,
    created_date DATE DEFAULT SYSDATE,
    CONSTRAINT fk_proj_manager FOREIGN KEY (project_manager_id) 
        REFERENCES employees(employee_id)
);

-- Table 3: TASKS
-- Main table for task tracking
CREATE TABLE tasks (
    task_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id NUMBER NOT NULL,
    assigned_to NUMBER NOT NULL,
    task_name VARCHAR2(200) NOT NULL,
    description VARCHAR2(1000),
    task_type VARCHAR2(30) DEFAULT 'Development' 
        CHECK (task_type IN ('Development', 'Testing', 'Design', 'Documentation', 
                             'Research', 'Meeting', 'Bug Fix', 'Deployment')),
    status VARCHAR2(20) DEFAULT 'Not Started' 
        CHECK (status IN ('Not Started', 'In Progress', 'On Hold', 'Completed', 
                         'Cancelled', 'Under Review')),
    priority VARCHAR2(10) DEFAULT 'Medium' 
        CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    start_date DATE,
    due_date DATE,
    completed_date DATE,
    estimated_hours NUMBER(6,2),
    actual_hours NUMBER(6,2),
    progress_percentage NUMBER(3) DEFAULT 0 
        CHECK (progress_percentage BETWEEN 0 AND 100),
    created_by NUMBER NOT NULL,
    created_date DATE DEFAULT SYSDATE,
    last_updated DATE DEFAULT SYSDATE,
    CONSTRAINT fk_task_project FOREIGN KEY (project_id) 
        REFERENCES projects(project_id) ON DELETE CASCADE,
    CONSTRAINT fk_task_assigned FOREIGN KEY (assigned_to) 
        REFERENCES employees(employee_id),
    CONSTRAINT fk_task_created FOREIGN KEY (created_by) 
        REFERENCES employees(employee_id)
);

-- Table 4: TASK_COMMENTS
-- Stores comments/notes on tasks
CREATE TABLE task_comments (
    comment_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_id NUMBER NOT NULL,
    employee_id NUMBER NOT NULL,
    comment_text VARCHAR2(2000) NOT NULL,
    comment_date DATE DEFAULT SYSDATE,
    CONSTRAINT fk_comment_task FOREIGN KEY (task_id) 
        REFERENCES tasks(task_id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_emp FOREIGN KEY (employee_id) 
        REFERENCES employees(employee_id)
);

-- Create Indexes for Performance
CREATE INDEX idx_emp_manager ON employees(manager_id);
CREATE INDEX idx_emp_department ON employees(department);
CREATE INDEX idx_proj_manager ON projects(project_manager_id);
CREATE INDEX idx_proj_status ON projects(status);
CREATE INDEX idx_task_project ON tasks(project_id);
CREATE INDEX idx_task_assigned ON tasks(assigned_to);
CREATE INDEX idx_task_status ON tasks(status);
CREATE INDEX idx_task_due_date ON tasks(due_date);
CREATE INDEX idx_comment_task ON task_comments(task_id);

-- Create Views for Reporting

-- View 1: Employee Task Summary
CREATE OR REPLACE VIEW vw_employee_task_summary AS
SELECT 
    e.employee_id,
    e.first_name || ' ' || e.last_name as employee_name,
    e.email,
    e.department,
    e.job_title,
    COUNT(t.task_id) as total_tasks,
    SUM(CASE WHEN t.status = 'Completed' THEN 1 ELSE 0 END) as completed_tasks,
    SUM(CASE WHEN t.status = 'In Progress' THEN 1 ELSE 0 END) as in_progress_tasks,
    SUM(CASE WHEN t.status = 'Not Started' THEN 1 ELSE 0 END) as pending_tasks,
    SUM(CASE WHEN t.due_date < SYSDATE AND t.status NOT IN ('Completed', 'Cancelled') 
        THEN 1 ELSE 0 END) as overdue_tasks,
    ROUND(AVG(t.progress_percentage), 2) as avg_progress
FROM employees e
LEFT JOIN tasks t ON e.employee_id = t.assigned_to
WHERE e.is_active = 'Y'
GROUP BY e.employee_id, e.first_name, e.last_name, e.email, e.department, e.job_title;

-- View 2: Project Task Statistics
CREATE OR REPLACE VIEW vw_project_task_stats AS
SELECT 
    p.project_id,
    p.project_name,
    p.project_code,
    p.status as project_status,
    p.priority as project_priority,
    COUNT(t.task_id) as total_tasks,
    SUM(CASE WHEN t.status = 'Completed' THEN 1 ELSE 0 END) as completed_tasks,
    SUM(CASE WHEN t.status = 'In Progress' THEN 1 ELSE 0 END) as in_progress_tasks,
    SUM(t.estimated_hours) as total_estimated_hours,
    SUM(t.actual_hours) as total_actual_hours,
    ROUND(AVG(t.progress_percentage), 2) as avg_task_progress,
    MIN(t.start_date) as earliest_task_start,
    MAX(t.due_date) as latest_task_due
FROM projects p
LEFT JOIN tasks t ON p.project_id = t.project_id
GROUP BY p.project_id, p.project_name, p.project_code, p.status, p.priority;

-- Triggers for Automatic Updates

-- Trigger 1: Update task last_updated timestamp
CREATE OR REPLACE TRIGGER trg_task_update
BEFORE UPDATE ON tasks
FOR EACH ROW
BEGIN
    :NEW.last_updated := SYSDATE;
    
    -- Auto-set completed_date when status changes to Completed
    IF :NEW.status = 'Completed' AND :OLD.status != 'Completed' THEN
        :NEW.completed_date := SYSDATE;
        :NEW.progress_percentage := 100;
    END IF;
END;
/

-- Trigger 2: Validate task dates
CREATE OR REPLACE TRIGGER trg_task_date_validation
BEFORE INSERT OR UPDATE ON tasks
FOR EACH ROW
BEGIN
    IF :NEW.due_date IS NOT NULL AND :NEW.start_date IS NOT NULL THEN
        IF :NEW.due_date < :NEW.start_date THEN
            RAISE_APPLICATION_ERROR(-20001, 'Due date cannot be before start date');
        END IF;
    END IF;
END;
/

-- Trigger 3: Update project completion based on tasks
CREATE OR REPLACE TRIGGER trg_update_project_completion
AFTER INSERT OR UPDATE OR DELETE ON tasks
FOR EACH ROW
DECLARE
    v_project_id NUMBER;
    v_avg_progress NUMBER;
BEGIN
    -- Get project_id
    IF DELETING THEN
        v_project_id := :OLD.project_id;
    ELSE
        v_project_id := :NEW.project_id;
    END IF;
    
    -- Calculate average progress
    SELECT NVL(AVG(progress_percentage), 0)
    INTO v_avg_progress
    FROM tasks
    WHERE project_id = v_project_id;
    
    -- Update project
    UPDATE projects
    SET completion_percentage = ROUND(v_avg_progress)
    WHERE project_id = v_project_id;
END;
/

COMMIT;