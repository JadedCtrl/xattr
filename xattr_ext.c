/*
 * Copyright 2022, Jaidyn Levesque <jadedctrl@posteo.at>
 *
 * This program is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */
#include <stdlib.h>
#include <sys/xattr.h>
#include <errno.h>


char*
get_xattr(const char* path, const char* attr, int* error_code)
{
	ssize_t value_size = getxattr(path, attr, NULL, 0);
	if (value_size == -1) {
		*error_code = errno;
		return NULL;
	}

	char* value = (char*) malloc(value_size + 1);
	ssize_t new_size = getxattr(path, attr, value, value_size + 1);
	*error_code = (new_size == -1) ? errno : 0;

	return value;
}


int
set_xattr(const char* path, const char* attr, const char* value, int* error_code)
{
	int retcode = lsetxattr(path, attr, value, strlen(value), 0);
	*error_code = (retcode == 0) ? 0 : errno;

	return retcode;
}


char*
list_xattr(const char* path, ssize_t* size, int* error_code)
{
	ssize_t value_size = llistxattr(path, NULL, 0);
	if (value_size == -1) {
		*error_code = errno;
		return NULL;
	}

	char* value = (char*) malloc(value_size + 1);
	*size = llistxattr(path, value, value_size + 1);
	*error_code = (*size == -1) ? errno : 0;
	return value;
}


int
remove_xattr(const char* path, const char* attr)
{
	if (lremovexattr(path, attr) == -1)
		return errno;
	else
		return 0;
}
