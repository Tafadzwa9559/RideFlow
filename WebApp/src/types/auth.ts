import type { Role } from "./user";
export interface Credentials {
  email: string;
  password: string;
}
export interface Registration extends Credentials {
  first_name: string;
  last_name: string;
  phone: string;
  role: Exclude<Role, "admin">;
}
export interface TokenResponse {
  access: string;
}
