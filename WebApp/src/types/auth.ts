export interface Credentials {
  email: string;
  password: string;
}
export interface Registration extends Credentials {
  first_name: string;
  last_name: string;
  password_confirmation: string;
}
export interface TokenResponse {
  access: string;
  refresh: string;
}
export interface StaffTokenResponse extends TokenResponse {
  user: {
    id: string;
    first_name: string;
    last_name: string;
    email: string;
    phone: string;
  };
}
