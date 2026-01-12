import type { FC } from 'react';
import '../styles/PasswordRequirements.css';

interface PasswordRequirement {
  label: string;
  test: (password: string) => boolean;
}

interface PasswordRequirementsProps {
  password: string;
}

const requirements: PasswordRequirement[] = [
  {
    label: 'At least 8 characters',
    test: (password: string) => password.length >= 8,
  },
  {
    label: 'At least one uppercase letter',
    test: (password: string) => /[A-Z]/.test(password),
  },
  {
    label: 'At least one number',
    test: (password: string) => /[0-9]/.test(password),
  },
  {
    label: 'At least one special character',
    test: (password: string) => /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]/.test(password),
  },
];

export const validatePassword = (password: string): boolean => {
  return requirements.every((req) => req.test(password));
};

const PasswordRequirements: FC<PasswordRequirementsProps> = ({ password }) => {
  return (
    <div className="password-requirements">
      <p className="requirements-title">Password must contain:</p>
      <ul className="requirements-list">
        {requirements.map((requirement, index) => {
          const isMet = requirement.test(password);
          return (
            <li
              key={index}
              className={`requirement-item ${isMet ? 'met' : 'unmet'}`}
            >
              <span className="requirement-icon">{isMet ? '✓' : '✗'}</span>
              <span className="requirement-text">{requirement.label}</span>
            </li>
          );
        })}
      </ul>
    </div>
  );
};

export default PasswordRequirements;
