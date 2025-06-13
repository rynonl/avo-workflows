# frozen_string_literal: true

# Migration to create employees table for advanced workflow examples
#
# This migration supports the comprehensive Employee model that demonstrates
# advanced workflow features including multiple employee types, complex 
# business rules, and rich context management.
#
# Employee Types Supported:
# - full_time: Standard employees with full benefits
# - contractor: Contract workers with limited access  
# - intern: Student interns with mentorship requirements
# - executive: C-level executives with special procedures

class CreateEmployees < ActiveRecord::Migration[7.0]
  def change
    create_table :employees do |t|
      # Core employee information
      t.string :name, null: false, limit: 100
      t.string :email, null: false, limit: 150
      t.string :employee_id, limit: 20, unique: true
      t.string :phone, limit: 20
      
      # Employment details
      t.string :employee_type, null: false, limit: 20
      t.string :department, null: false, limit: 50
      t.string :job_title, limit: 100
      t.string :salary_level, null: false, limit: 20
      t.date :start_date, null: false
      t.date :end_date
      
      # Security and access
      t.string :security_clearance, limit: 20
      t.text :special_requirements
      
      # Organizational relationships
      t.references :manager, null: true, foreign_key: { to_table: :users }
      t.references :mentor, null: true, foreign_key: { to_table: :users }
      t.references :hr_representative, null: true, foreign_key: { to_table: :users }
      
      # Contact and personal information
      t.text :address
      t.string :emergency_contact_name, limit: 100
      t.string :emergency_contact_phone, limit: 20
      
      # Status and tracking
      t.string :status, default: 'pending_onboarding', limit: 30
      t.text :notes
      t.json :additional_data # For storing flexible employee attributes
      
      # Performance indexes for common queries
      t.index :email, unique: true
      t.index :employee_id, unique: true
      t.index :employee_type
      t.index :department
      t.index :start_date
      t.index :status
      t.index [:department, :employee_type] # Composite index for filtering
      t.index [:manager_id, :status] # For manager dashboards
      t.index [:start_date, :status] # For onboarding timelines
      
      t.timestamps
    end
    
    # Add check constraints for data integrity
    
    # Employee type constraint
    add_check_constraint :employees, 
      "employee_type IN ('full_time', 'contractor', 'intern', 'executive')", 
      name: "employees_valid_employee_type"
    
    # Department constraint  
    add_check_constraint :employees,
      "department IN ('Engineering', 'Marketing', 'Sales', 'HR', 'Finance', 'Operations', 'Legal', 'Customer_Success', 'Product', 'Design', 'Security')",
      name: "employees_valid_department"
    
    # Security clearance constraint
    add_check_constraint :employees,
      "security_clearance IS NULL OR security_clearance IN ('none', 'standard', 'confidential', 'secret', 'top_secret')",
      name: "employees_valid_security_clearance"
    
    # Salary level constraint
    add_check_constraint :employees,
      "salary_level IN ('junior', 'mid', 'senior', 'staff', 'principal', 'executive', 'c_level')",
      name: "employees_valid_salary_level"
    
    # Status constraint
    add_check_constraint :employees,
      "status IN ('pending_onboarding', 'onboarding_in_progress', 'active', 'on_leave', 'terminated', 'contractor_ended')",
      name: "employees_valid_status"
    
    # Start date constraint (must be reasonable)
    add_check_constraint :employees,
      "start_date >= '2020-01-01' AND start_date <= DATE('now', '+2 years')",
      name: "employees_reasonable_start_date"
    
    # End date constraint (if present, must be after start date)
    add_check_constraint :employees,
      "end_date IS NULL OR end_date > start_date",
      name: "employees_end_date_after_start"
    
    # Name constraint (minimum length)
    add_check_constraint :employees,
      "LENGTH(TRIM(name)) >= 2",
      name: "employees_name_minimum_length"
    
    # Email format constraint (basic validation)
    add_check_constraint :employees,
      "email LIKE '%@%.%' AND LENGTH(email) >= 5",
      name: "employees_email_basic_format"
  end
end