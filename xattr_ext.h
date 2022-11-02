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
#ifndef _SCM_XATTR_H
#define _SCM_XATTR_H

char* get_xattr(const char* path, const char* attr, int* error_code);

int set_xattr(const char* path, const char* attr, const char* value, int* error_code);

char* list_xattr(const char* path, ssize_t* size, int* error_code);

int remove_xattr(const char* path, const char* attr);

#endif // _SCM_XATTR_H
