import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import React, { ReactNode } from "react";
import { useCurrentUser } from "./useCurrentUser";
import { userGetInfoV2 } from "@/components/networking";
import type { UserInfoV2Response } from "@/components/networking";

vi.mock("@/components/networking", () => ({
  userGetInfoV2: vi.fn(),
}));

vi.mock("../common/queryKeysFactory", () => ({
  createQueryKeys: vi.fn((resource: string) => ({
    all: [resource],
    lists: () => [resource, "list"],
    list: (params?: any) => [resource, "list", { params }],
    details: () => [resource, "detail"],
    detail: (uid: string) => [resource, "detail", uid],
  })),
}));

const mockUseAuthorized = vi.fn();
vi.mock("@/app/(dashboard)/hooks/useAuthorized", () => ({
  default: () => mockUseAuthorized(),
}));

const mockUserInfoV2Response: UserInfoV2Response = {
  user_id: "test-user-id",
  user_email: "test@example.com",
  user_alias: "Test User",
  user_role: "internal_user",
  spend: 150.75,
  max_budget: 1000.0,
  models: ["gpt-4"],
  budget_duration: "monthly",
  budget_reset_at: null,
  metadata: null,
  created_at: "2024-01-01T00:00:00Z",
  updated_at: "2024-01-01T00:00:00Z",
  password_expiry: "2030-01-01T00:00:00Z",
  sso_user_id: null,
  teams: ["team-1"],
};

describe("useCurrentUser", () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: {
          retry: false,
        },
      },
    });

    vi.clearAllMocks();

    mockUseAuthorized.mockReturnValue({
      accessToken: "test-access-token",
      userId: "test-user-id",
      userRole: "Admin",
      token: "test-token",
      userEmail: "test@example.com",
      premiumUser: false,
      disabledPersonalKeyCreation: null,
      showSSOBanner: false,
    });
  });

  const wrapper = ({ children }: { children: ReactNode }) =>
    React.createElement(QueryClientProvider, { client: queryClient }, children);

  it("should return user info data when query is successful", async () => {
    (userGetInfoV2 as any).mockResolvedValue(mockUserInfoV2Response);

    const { result } = renderHook(() => useCurrentUser(), { wrapper });

    expect(result.current.isLoading).toBe(true);
    expect(result.current.data).toBeUndefined();

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data).toEqual(mockUserInfoV2Response);
    expect(result.current.error).toBeNull();
    expect(userGetInfoV2).toHaveBeenCalledWith("test-access-token");
    expect(userGetInfoV2).toHaveBeenCalledTimes(1);
  });

  it("should handle error when userGetInfoV2 fails", async () => {
    const testError = new Error("Failed to fetch user info");
    (userGetInfoV2 as any).mockRejectedValue(testError);

    const { result } = renderHook(() => useCurrentUser(), { wrapper });

    expect(result.current.isLoading).toBe(true);

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
      expect(result.current.isError).toBe(true);
    });

    expect(result.current.error).toEqual(testError);
    expect(result.current.data).toBeUndefined();
    expect(userGetInfoV2).toHaveBeenCalledWith("test-access-token");
    expect(userGetInfoV2).toHaveBeenCalledTimes(1);
  });

  it("should not execute query when accessToken is missing", async () => {
    mockUseAuthorized.mockReturnValue({
      accessToken: null,
      userId: "test-user-id",
      userRole: "Admin",
      token: null,
      userEmail: "test@example.com",
      premiumUser: false,
      disabledPersonalKeyCreation: null,
      showSSOBanner: false,
    });

    const { result } = renderHook(() => useCurrentUser(), { wrapper });

    expect(result.current.isLoading).toBe(false);
    expect(result.current.data).toBeUndefined();
    expect(result.current.isFetched).toBe(false);
    expect(userGetInfoV2).not.toHaveBeenCalled();
  });

  it("should not execute query when userId is missing", async () => {
    mockUseAuthorized.mockReturnValue({
      accessToken: "test-access-token",
      userId: null,
      userRole: "Admin",
      token: "test-token",
      userEmail: "test@example.com",
      premiumUser: false,
      disabledPersonalKeyCreation: null,
      showSSOBanner: false,
    });

    const { result } = renderHook(() => useCurrentUser(), { wrapper });

    expect(result.current.isLoading).toBe(false);
    expect(result.current.data).toBeUndefined();
    expect(result.current.isFetched).toBe(false);
    expect(userGetInfoV2).not.toHaveBeenCalled();
  });

  it("should expose password_expiry when present", async () => {
    (userGetInfoV2 as any).mockResolvedValue(mockUserInfoV2Response);

    const { result } = renderHook(() => useCurrentUser(), { wrapper });

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true);
    });

    expect(result.current.data?.password_expiry).toBe("2030-01-01T00:00:00Z");
  });
});
