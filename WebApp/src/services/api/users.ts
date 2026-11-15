import { api } from "./client";
import type { User } from "../../types/user";
import type { Page } from "../../types/api";
export const usersService = {
  list: (search = "", page = 1) =>
    api.get<Page<User>>("/users/", { params: { search, page } }),
  get: () => api.get<User>("/users/me/"),
  update: (data: Partial<Omit<User, "id" | "role">>) =>
    api.patch<User>("/users/me/", data),
};
export const profileService = usersService;
