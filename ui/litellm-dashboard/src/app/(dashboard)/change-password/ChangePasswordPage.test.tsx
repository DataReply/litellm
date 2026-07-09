import { renderWithProviders, screen, waitFor } from "../../../../tests/test-utils";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import ChangePasswordPage from "./ChangePasswordPage";

const mockUseAuthorized = vi.fn();
const mockUseCurrentUser = vi.fn();
const mockInvalidateQueries = vi.fn();
const mockSuccess = vi.fn();
const mockError = vi.fn();
const mockChangePasswordCall = vi.fn();

vi.mock("@/app/(dashboard)/hooks/useAuthorized", () => ({
  default: () => mockUseAuthorized(),
}));

vi.mock("@/app/(dashboard)/hooks/users/useCurrentUser", () => ({
  useCurrentUser: () => mockUseCurrentUser(),
}));

vi.mock("@/components/molecules/message_manager", () => ({
  default: {
    success: (...args: unknown[]) => mockSuccess(...args),
    error: (...args: unknown[]) => mockError(...args),
  },
}));

vi.mock("@/components/networking", () => ({
  changePasswordCall: (...args: unknown[]) => mockChangePasswordCall(...args),
}));

vi.mock("@tanstack/react-query", async () => {
  const actual = await vi.importActual<typeof import("@tanstack/react-query")>("@tanstack/react-query");
  return {
    ...actual,
    useQueryClient: () => ({
      invalidateQueries: (...args: unknown[]) => mockInvalidateQueries(...args),
    }),
  };
});

describe("ChangePasswordPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockUseAuthorized.mockReturnValue({ accessToken: "access-token" });
    mockUseCurrentUser.mockReturnValue({
      data: {
        user_id: "user-1",
        password_expiry: "2030-01-01T00:00:00Z",
      },
    });
    mockInvalidateQueries.mockResolvedValue(undefined);
    mockChangePasswordCall.mockResolvedValue({
      message: "Password updated successfully",
      password_expiry: "2030-02-01T00:00:00Z",
    });
  });

  it("renders the page heading and current expiry", () => {
    renderWithProviders(<ChangePasswordPage />);

    expect(screen.getByRole("heading", { name: "Change password" })).toBeInTheDocument();
    expect(screen.getByText(/Current password expires on/i)).toBeInTheDocument();
  });

  it("validates that the new passwords match", async () => {
    const user = userEvent.setup();
    renderWithProviders(<ChangePasswordPage />);

    await user.type(screen.getByLabelText("Current password"), "old-pass");
    await user.type(screen.getByLabelText("New password"), "new-pass-1");
    await user.type(screen.getByLabelText("Confirm new password"), "new-pass-2");
    await user.click(screen.getByRole("button", { name: "Change password" }));

    await waitFor(() => {
      expect(screen.getByText("New passwords do not match")).toBeInTheDocument();
    });

    expect(mockChangePasswordCall).not.toHaveBeenCalled();
  });

  it("submits the change password request and shows success", async () => {
    const user = userEvent.setup();
    renderWithProviders(<ChangePasswordPage />);

    await user.type(screen.getByLabelText("Current password"), "old-pass");
    await user.type(screen.getByLabelText("New password"), "new-pass");
    await user.type(screen.getByLabelText("Confirm new password"), "new-pass");
    await user.click(screen.getByRole("button", { name: "Change password" }));

    await waitFor(() => {
      expect(mockChangePasswordCall).toHaveBeenCalledWith("access-token", "old-pass", "new-pass");
    });
    await waitFor(() => {
      expect(mockSuccess).toHaveBeenCalledWith("Password updated successfully");
    });
    expect(mockInvalidateQueries).toHaveBeenCalledWith({ queryKey: ["users"] });
  });
});
